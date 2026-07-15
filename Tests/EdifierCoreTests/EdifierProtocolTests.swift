import EdifierCore
import XCTest

final class EdifierProtocolTests: XCTestCase {
    func testVolumeReadFrame() {
        XCTAssertEqual(
            EdifierProtocol.request(command: .volumeRead),
            Data([0xAA, 0xEC, 0x66, 0x00, 0x00, 0xFC])
        )
    }

    func testVolumeWriteFrame() {
        XCTAssertEqual(
            EdifierProtocol.request(command: .volumeWrite, payload: Data([24])),
            Data([0xAA, 0xEC, 0x67, 0x00, 0x01, 0x18, 0x16])
        )
    }

    func testBluetoothSourceFrame() {
        XCTAssertEqual(
            EdifierProtocol.request(command: .sourceWrite, payload: Data([0x10, 0x04])),
            Data([0xAA, 0xEC, 0x62, 0x00, 0x02, 0x10, 0x04, 0x0E])
        )
    }

    func testEQValueMapping() {
        XCTAssertEqual(SpeakerEQ.monitor.rawValue, 1)
        XCTAssertEqual(SpeakerEQ.dynamic.rawValue, 2)
        XCTAssertEqual(SpeakerEQ.classic.rawValue, 0)
        XCTAssertEqual(SpeakerEQ.vocal.rawValue, 3)
        XCTAssertEqual(SpeakerEQ.customized.rawValue, 4)
    }

    func testMonitorEQFrame() {
        XCTAssertEqual(
            EdifierProtocol.request(command: .eqWrite, payload: Data([SpeakerEQ.monitor.rawValue])),
            Data([0xAA, 0xEC, 0xC4, 0x00, 0x01, 0x01, 0x5C])
        )
    }

    func testParsesVolumeResponse() throws {
        let message = try EdifierProtocol.parse(
            Data([0xBB, 0xEC, 0x67, 0x00, 0x02, 0x1E, 0x18, 0x46])
        )
        XCTAssertEqual(message.direction, .response)
        XCTAssertEqual(message.command, EdifierCommand.volumeWrite.rawValue)
        XCTAssertEqual(message.payload, Data([30, 24]))
    }

    func testRejectsInvalidChecksum() {
        XCTAssertThrowsError(
            try EdifierProtocol.parse(Data([0xBB, 0xEC, 0x67, 0x00, 0x02, 0x1E, 0x18, 0x00]))
        ) { error in
            XCTAssertEqual(error as? EdifierProtocolError, .invalidChecksum)
        }
    }
}
