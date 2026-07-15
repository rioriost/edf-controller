import Foundation

public enum CustomEQCodecError: Error, Equatable {
    case invalidHeader
    case invalidLength
    case invalidBand
    case invalidGain
}

public enum CustomEQCodec {
    public static let frequencies: [UInt16] = [62, 250, 1_000, 4_000, 8_000, 16_000]
    public static let minimumGain = -3.0
    public static let maximumGain = 3.0
    public static let gainStep = 0.5

    public static var neutralGains: [Double] {
        Array(repeating: 0, count: frequencies.count)
    }

    public static func normalizedGain(_ gain: Double) -> Double {
        let clamped = min(max(gain, minimumGain), maximumGain)
        return ((clamped - minimumGain) / gainStep).rounded() * gainStep + minimumGain
    }

    public static func writePayload(bandIndex: Int, gain: Double) -> Data? {
        guard frequencies.indices.contains(bandIndex) else { return nil }

        let frequency = frequencies[bandIndex]
        let normalized = normalizedGain(gain)
        let encodedGain = UInt8(((normalized - minimumGain) / gainStep).rounded())

        return Data([
            UInt8(bandIndex),
            0x00,
            UInt8(frequency >> 8),
            UInt8(frequency & 0xFF),
            encodedGain,
            0x07,
        ])
    }

    public static func decodeReadPayload(_ payload: Data) throws -> [Double] {
        let bytes = [UInt8](payload)
        guard bytes.count >= 2, bytes[0] == 0x03, bytes[1] == frequencies.count else {
            throw CustomEQCodecError.invalidHeader
        }

        let recordsLength = frequencies.count * 6
        guard bytes.count >= 2 + recordsLength else {
            throw CustomEQCodecError.invalidLength
        }

        var gains = neutralGains
        for recordIndex in frequencies.indices {
            let offset = 2 + recordIndex * 6
            let bandIndex = Int(bytes[offset])
            guard frequencies.indices.contains(bandIndex) else {
                throw CustomEQCodecError.invalidBand
            }

            let frequency = UInt16(bytes[offset + 2]) << 8 | UInt16(bytes[offset + 3])
            guard frequency == frequencies[bandIndex] else {
                throw CustomEQCodecError.invalidBand
            }

            let encodedGain = bytes[offset + 4]
            guard encodedGain <= 12 else {
                throw CustomEQCodecError.invalidGain
            }
            gains[bandIndex] = Double(encodedGain) * gainStep + minimumGain
        }
        return gains
    }
}
