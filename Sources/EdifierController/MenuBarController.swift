import AppKit
import Combine
import EdifierCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let speakerController: SpeakerController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let sourceItems: [SpeakerSource: NSMenuItem]
    private let eqItems: [SpeakerEQ: NSMenuItem]
    private let volumeView = VolumeMenuItemView()
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindowController: SettingsWindowController?

    init(speakerController: SpeakerController) {
        self.speakerController = speakerController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        var sources: [SpeakerSource: NSMenuItem] = [:]
        for source in SpeakerSource.allCases {
            sources[source] = NSMenuItem(title: source.displayName, action: nil, keyEquivalent: "")
        }
        sourceItems = sources

        var modes: [SpeakerEQ: NSMenuItem] = [:]
        for eq in SpeakerEQ.allCases {
            modes[eq] = NSMenuItem(title: eq.displayName, action: nil, keyEquivalent: "")
        }
        eqItems = modes

        super.init()
        configureStatusItem()
        configureMenu()
        observeState()
    }

    private func configureStatusItem() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "hifispeaker.2.fill",
            accessibilityDescription: "Edf Controller"
        )
        statusItem.button?.toolTip = "Edf Controller"
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        let sourceMenu = NSMenu(title: "Source")
        for source in SpeakerSource.allCases {
            guard let item = sourceItems[source] else { continue }
            item.target = self
            item.action = #selector(selectSource(_:))
            item.representedObject = NSNumber(value: source.rawValue)
            sourceMenu.addItem(item)
        }
        let sourceRoot = NSMenuItem(title: "Source", action: nil, keyEquivalent: "")
        sourceRoot.submenu = sourceMenu
        menu.addItem(sourceRoot)

        let eqMenu = NSMenu(title: "EQ")
        for eq in SpeakerEQ.allCases {
            guard let item = eqItems[eq] else { continue }
            item.target = self
            item.action = #selector(selectEQ(_:))
            item.representedObject = NSNumber(value: eq.rawValue)
            eqMenu.addItem(item)
        }
        let eqRoot = NSMenuItem(title: "EQ", action: nil, keyEquivalent: "")
        eqRoot.submenu = eqMenu
        menu.addItem(eqRoot)

        menu.addItem(.separator())

        let volumeLabel = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeLabel.isEnabled = false
        menu.addItem(volumeLabel)

        let volumeItem = NSMenuItem()
        volumeItem.view = volumeView
        menu.addItem(volumeItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        volumeView.onVolumeChanged = { [weak speakerController] value in
            speakerController?.setVolumeDebounced(value)
        }
    }

    private func observeState() {
        Publishers.CombineLatest4(
            speakerController.$connectionState,
                speakerController.$source,
                speakerController.$eq,
                speakerController.$volume
        )
            .combineLatest(speakerController.$maximumVolume)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] combined, maximumVolume in
                let (state, source, eq, volume) = combined
                self?.updateMenu(
                    state: state,
                    source: source,
                    eq: eq,
                    volume: volume,
                    maximumVolume: maximumVolume
                )
            }
            .store(in: &cancellables)
    }

    private func updateMenu(
        state: SpeakerConnectionState,
        source: SpeakerSource?,
        eq: SpeakerEQ?,
        volume: Int,
        maximumVolume: Int
    ) {
        let enabled = state.isReady
        statusItem.button?.appearsDisabled = !enabled
        statusItem.button?.toolTip = "Edf Controller — \(state.description)"

        for (value, item) in sourceItems {
            item.isEnabled = enabled
            item.state = value == source ? .on : .off
        }
        for (value, item) in eqItems {
            item.isEnabled = enabled
            item.state = value == eq ? .on : .off
        }
        volumeView.update(value: volume, maximum: maximumVolume, isEnabled: enabled)
    }

    func menuWillOpen(_ menu: NSMenu) {
        speakerController.refreshState()
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber,
              let source = SpeakerSource(rawValue: number.uint8Value)
        else { return }
        speakerController.selectSource(source)
    }

    @objc private func selectEQ(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber,
              let eq = SpeakerEQ(rawValue: number.uint8Value)
        else { return }
        speakerController.selectEQ(eq)
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(speakerController: speakerController)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
