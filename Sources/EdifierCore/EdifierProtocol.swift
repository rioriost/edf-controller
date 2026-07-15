import Foundation

public enum EdifierCommand: UInt16, Sendable {
    case customEQRead = 0x0043
    case customEQWrite = 0x0044
    case sourceStatus = 0x0061
    case sourceWrite = 0x0062
    case volumeRead = 0x0066
    case volumeWrite = 0x0067
    case playbackStatus = 0x0068
    case eqWrite = 0x00C4
    case modelName = 0x00C9
    case capability = 0x00D8
    case eqStatus = 0x00D5
}

public enum EdifierMessageDirection: Sendable {
    case request
    case response
}

public struct EdifierMessage: Equatable, Sendable {
    public let direction: EdifierMessageDirection
    public let command: UInt16
    public let payload: Data

    public init(direction: EdifierMessageDirection, command: UInt16, payload: Data) {
        self.direction = direction
        self.command = command
        self.payload = payload
    }
}

public enum EdifierProtocolError: Error, Equatable {
    case tooShort
    case invalidHeader
    case invalidLength
    case invalidChecksum
}

public enum EdifierProtocol {
    private static let requestHeader: [UInt8] = [0xAA, 0xEC]
    private static let responseHeader: [UInt8] = [0xBB, 0xEC]

    public static func request(command: EdifierCommand, payload: Data = Data()) -> Data {
        precondition(payload.count <= UInt8.max, "Payload is too large")

        var bytes = requestHeader
        bytes.append(UInt8(command.rawValue & 0xFF))
        bytes.append(UInt8(command.rawValue >> 8))
        bytes.append(UInt8(payload.count))
        bytes.append(contentsOf: payload)
        bytes.append(checksum(bytes))
        return Data(bytes)
    }

    public static func parse(_ data: Data) throws -> EdifierMessage {
        let bytes = [UInt8](data)
        guard bytes.count >= 6 else { throw EdifierProtocolError.tooShort }

        let direction: EdifierMessageDirection
        switch Array(bytes.prefix(2)) {
        case requestHeader:
            direction = .request
        case responseHeader:
            direction = .response
        default:
            throw EdifierProtocolError.invalidHeader
        }

        let payloadLength = Int(bytes[4])
        guard bytes.count == payloadLength + 6 else {
            throw EdifierProtocolError.invalidLength
        }
        guard bytes.last == checksum(Array(bytes.dropLast())) else {
            throw EdifierProtocolError.invalidChecksum
        }

        let command = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        let payload = Data(bytes[5..<(5 + payloadLength)])
        return EdifierMessage(direction: direction, command: command, payload: payload)
    }

    private static func checksum(_ bytes: [UInt8]) -> UInt8 {
        UInt8(truncatingIfNeeded: bytes.reduce(0) { $0 + UInt($1) })
    }
}
