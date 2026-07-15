import Foundation

public enum SpeakerSource: UInt8, CaseIterable, Identifiable, Sendable {
    case usbAudioStreaming = 1
    case lineIn1 = 2
    case lineIn2 = 3
    case bluetooth = 4
    case optical = 5
    case coaxial = 6

    public var id: UInt8 { rawValue }

    public var displayName: String {
        switch self {
        case .usbAudioStreaming: "USB Audio Streaming"
        case .lineIn1: "Line In 1"
        case .lineIn2: "Line In 2"
        case .bluetooth: "Bluetooth"
        case .optical: "Optical"
        case .coaxial: "Coaxial"
        }
    }
}

public enum SpeakerEQ: UInt8, CaseIterable, Identifiable, Sendable {
    case monitor = 1
    case dynamic = 2
    case classic = 0
    case vocal = 3
    case customized = 4

    public var id: UInt8 { rawValue }

    public var displayName: String {
        switch self {
        case .monitor: "Monitor"
        case .dynamic: "Dynamic"
        case .classic: "Classic"
        case .vocal: "Vocal"
        case .customized: "Customized"
        }
    }
}
