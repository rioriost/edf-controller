import Combine
@preconcurrency import CoreBluetooth
import EdifierCore
import Foundation

struct SpeakerOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int

    var displayName: String {
        "\(name) (\(rssi) dBm)"
    }
}

enum SpeakerConnectionState: Equatable {
    case bluetoothUnavailable
    case scanning
    case connecting(String)
    case connected(String)
    case disconnected
    case failed(String)

    var description: String {
        switch self {
        case .bluetoothUnavailable: "Bluetooth unavailable"
        case .scanning: "Searching for S880DB MKII…"
        case let .connecting(name): "Connecting to \(name)…"
        case let .connected(name): "Connected to \(name)"
        case .disconnected: "Not connected"
        case let .failed(message): "Connection failed: \(message)"
        }
    }

    var isReady: Bool {
        if case .connected = self { return true }
        return false
    }
}

@MainActor
final class SpeakerController: NSObject, ObservableObject {
    static let advertisedServiceUUID = CBUUID(string: "F100")
    static let controlServiceUUID = CBUUID(string: "4809F101-1A48-11E9-AB14-D663BD873D93")
    static let receiveCharacteristicUUID = CBUUID(string: "48090001-1A48-11E9-AB14-D663BD873D93")
    static let transmitCharacteristicUUID = CBUUID(string: "48090002-1A48-11E9-AB14-D663BD873D93")

    @Published private(set) var connectionState: SpeakerConnectionState = .scanning
    @Published private(set) var discoveredSpeakers: [SpeakerOption] = []
    @Published private(set) var source: SpeakerSource?
    @Published private(set) var eq: SpeakerEQ?
    @Published private(set) var volume: Int = 0
    @Published private(set) var maximumVolume: Int = 30
    @Published private(set) var selectedSpeakerID: UUID?
    @Published private(set) var customEQGains: [Double] = CustomEQCodec.neutralGains

    private static let selectedSpeakerKey = "SelectedSpeakerIdentifier"
    private static let automaticSelection = "automatic"

    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var signalStrength: [UUID: Int] = [:]
    private var activePeripheral: CBPeripheral?
    private var receiveCharacteristic: CBCharacteristic?
    private var transmitCharacteristic: CBCharacteristic?
    private var pendingWrites: [Data] = []
    private var writeInFlight = false
    private var autoConnectWorkItem: DispatchWorkItem?
    private var volumeWorkItem: DispatchWorkItem?
    private var customEQWorkItems: [Int: DispatchWorkItem] = [:]

    override init() {
        let stored = UserDefaults.standard.string(forKey: Self.selectedSpeakerKey)
        if let stored, stored != Self.automaticSelection {
            selectedSpeakerID = UUID(uuidString: stored)
        }
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    var usesAutomaticSelection: Bool {
        selectedSpeakerID == nil
    }

    func selectAutomatic() {
        selectedSpeakerID = nil
        UserDefaults.standard.set(Self.automaticSelection, forKey: Self.selectedSpeakerKey)
        reconnectForSelectionChange()
    }

    func selectSpeaker(id: UUID) {
        selectedSpeakerID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedSpeakerKey)
        reconnectForSelectionChange()
    }

    func rescan() {
        guard centralManager.state == .poweredOn else { return }
        discoveredSpeakers = []
        peripherals = [:]
        signalStrength = [:]
        if let activePeripheral {
            peripherals[activePeripheral.identifier] = activePeripheral
            updateDiscoveredSpeaker(activePeripheral, rssi: -127)
        } else {
            connectionState = .scanning
        }
        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func refreshState() {
        guard connectionState.isReady else { return }
        enqueue(.sourceStatus)
        enqueue(.volumeRead)
        enqueue(.eqStatus)
        enqueue(.customEQRead)
    }

    func selectSource(_ source: SpeakerSource) {
        guard connectionState.isReady else { return }
        self.source = source
        enqueue(.sourceWrite, payload: Data([0x10, source.rawValue]))
    }

    func selectEQ(_ eq: SpeakerEQ) {
        guard connectionState.isReady else { return }
        self.eq = eq
        enqueue(.eqWrite, payload: Data([eq.rawValue]))
    }

    func setVolumeDebounced(_ newValue: Int) {
        let clamped = min(max(newValue, 0), maximumVolume)
        volume = clamped
        volumeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.enqueue(.volumeWrite, payload: Data([UInt8(clamped)]))
        }
        volumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    func refreshCustomEQ() {
        guard connectionState.isReady else { return }
        enqueue(.customEQRead)
    }

    func setCustomEQGain(bandIndex: Int, gain: Double) {
        guard connectionState.isReady,
              customEQGains.indices.contains(bandIndex),
              let payload = CustomEQCodec.writePayload(bandIndex: bandIndex, gain: gain)
        else { return }

        let normalized = CustomEQCodec.normalizedGain(gain)
        var updatedGains = customEQGains
        updatedGains[bandIndex] = normalized
        customEQGains = updatedGains

        if eq != .customized {
            selectEQ(.customized)
        }

        customEQWorkItems[bandIndex]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.customEQWorkItems[bandIndex] = nil
            self.enqueue(.customEQWrite, payload: payload)
        }
        customEQWorkItems[bandIndex] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func reconnectForSelectionChange() {
        autoConnectWorkItem?.cancel()
        if let activePeripheral {
            connectionState = .disconnected
            centralManager.cancelPeripheralConnection(activePeripheral)
            return
        }
        clearConnection()
        startSelectionSearch()
    }

    private func startSelectionSearch() {
        rescan()

        if let selectedSpeakerID,
           let known = centralManager.retrievePeripherals(withIdentifiers: [selectedSpeakerID]).first
        {
            connect(to: known)
        }
    }

    private func isCompatible(
        peripheral: CBPeripheral,
        advertisementData: [String: Any]
    ) -> Bool {
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        return advertisedServices.contains(Self.advertisedServiceUUID)
            || advertisedServices.contains(Self.controlServiceUUID)
            || name.localizedCaseInsensitiveContains("EDIFIER BLE")
    }

    private func scheduleAutomaticConnection() {
        guard selectedSpeakerID == nil, activePeripheral == nil, autoConnectWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.autoConnectWorkItem = nil
            guard self.activePeripheral == nil else { return }
            let best = self.signalStrength.max { $0.value < $1.value }?.key
            if let best, let peripheral = self.peripherals[best] {
                self.connect(to: peripheral)
            }
        }
        autoConnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func connect(to peripheral: CBPeripheral) {
        guard activePeripheral == nil else { return }
        activePeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting(peripheral.name ?? "EDIFIER S880DB MKII")
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    private func clearConnection() {
        activePeripheral = nil
        receiveCharacteristic = nil
        transmitCharacteristic = nil
        pendingWrites = []
        writeInFlight = false
        source = nil
        eq = nil
        customEQWorkItems.values.forEach { $0.cancel() }
        customEQWorkItems = [:]
        customEQGains = CustomEQCodec.neutralGains
    }

    private func enqueue(_ command: EdifierCommand, payload: Data = Data()) {
        guard transmitCharacteristic != nil else { return }
        pendingWrites.append(EdifierProtocol.request(command: command, payload: payload))
        writeNextIfPossible()
    }

    private func writeNextIfPossible() {
        guard !writeInFlight,
              !pendingWrites.isEmpty,
              let activePeripheral,
              let transmitCharacteristic
        else { return }

        writeInFlight = true
        activePeripheral.writeValue(
            pendingWrites.removeFirst(),
            for: transmitCharacteristic,
            type: .withResponse
        )
    }

    private func handleNotification(_ data: Data) {
        guard let message = try? EdifierProtocol.parse(data) else { return }

        switch message.command {
        case EdifierCommand.sourceStatus.rawValue:
            if message.payload.count >= 2, message.payload[0] == 0x10 {
                source = SpeakerSource(rawValue: message.payload[1])
            }
        case EdifierCommand.volumeRead.rawValue, EdifierCommand.volumeWrite.rawValue:
            if message.payload.count >= 2 {
                maximumVolume = Int(message.payload[0])
                volume = Int(message.payload[1])
            }
        case EdifierCommand.eqStatus.rawValue, EdifierCommand.eqWrite.rawValue:
            if let value = message.payload.first {
                eq = SpeakerEQ(rawValue: value)
            }
        case EdifierCommand.customEQRead.rawValue:
            if let gains = try? CustomEQCodec.decodeReadPayload(message.payload) {
                customEQGains = gains
            }
        default:
            break
        }
    }

    private func updateDiscoveredSpeaker(_ peripheral: CBPeripheral, rssi: Int) {
        peripherals[peripheral.identifier] = peripheral
        signalStrength[peripheral.identifier] = rssi
        discoveredSpeakers = peripherals.values.map { item in
            SpeakerOption(
                id: item.identifier,
                name: item.name ?? "EDIFIER S880DB MKII",
                rssi: signalStrength[item.identifier] ?? -127
            )
        }
        .sorted { lhs, rhs in
            if lhs.rssi == rhs.rssi { return lhs.name < rhs.name }
            return lhs.rssi > rhs.rssi
        }
    }
}

extension SpeakerController: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            clearConnection()
            connectionState = .bluetoothUnavailable
            return
        }

        rescan()
        if let selectedSpeakerID,
           let known = central.retrievePeripherals(withIdentifiers: [selectedSpeakerID]).first
        {
            connect(to: known)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isCompatible(peripheral: peripheral, advertisementData: advertisementData) else { return }
        updateDiscoveredSpeaker(peripheral, rssi: RSSI.intValue)

        if let selectedSpeakerID {
            if peripheral.identifier == selectedSpeakerID, activePeripheral == nil {
                connect(to: peripheral)
            }
        } else {
            scheduleAutomaticConnection()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.controlServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard activePeripheral?.identifier == peripheral.identifier else { return }
        clearConnection()
        connectionState = .failed(error?.localizedDescription ?? "Unknown error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startSelectionSearch()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard activePeripheral?.identifier == peripheral.identifier else { return }
        clearConnection()
        connectionState = error.map { .failed($0.localizedDescription) } ?? .disconnected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startSelectionSearch()
        }
    }
}

extension SpeakerController: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectionState = .failed(error.localizedDescription)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.controlServiceUUID }) else {
            connectionState = .failed("Control service not found")
            return
        }
        peripheral.discoverCharacteristics(
            [Self.receiveCharacteristicUUID, Self.transmitCharacteristicUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            connectionState = .failed(error.localizedDescription)
            return
        }

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.receiveCharacteristicUUID:
                receiveCharacteristic = characteristic
            case Self.transmitCharacteristicUUID:
                transmitCharacteristic = characteristic
            default:
                break
            }
        }

        guard let receiveCharacteristic, transmitCharacteristic != nil else {
            connectionState = .failed("Control characteristics not found")
            return
        }
        peripheral.setNotifyValue(true, for: receiveCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            connectionState = .failed(error.localizedDescription)
            return
        }
        guard characteristic.uuid == Self.receiveCharacteristicUUID, characteristic.isNotifying else { return }

        connectionState = .connected(peripheral.name ?? "EDIFIER S880DB MKII")
        enqueue(.capability)
        refreshState()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.receiveCharacteristicUUID,
              let value = characteristic.value
        else { return }
        handleNotification(value)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        writeInFlight = false
        if let error {
            connectionState = .failed(error.localizedDescription)
            pendingWrites = []
            return
        }
        writeNextIfPossible()
    }
}
