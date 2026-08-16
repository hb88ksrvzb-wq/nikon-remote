import XCTest
@testable import NikonRemote

final class ProtocolEncodingTests: XCTestCase {

    func testPTPStringDecodingConsumesLengthPrefixedUTF16LEValue() throws {
        var reader = ByteReader([
            0x04,
            0x5A, 0x00, 0x20, 0x00, 0x38, 0x00, 0x00, 0x00,
            0xA5
        ])

        XCTAssertEqual(try reader.readPTPString(), "Z 8")
        XCTAssertEqual(try reader.readUInt8(), 0xA5)
    }

    func testPTPStringEncodingUsesCharacterCountAndUTF16LETerminator() {
        var encoded: [UInt8] = []

        ByteWriter.appendPTPString("Z8", to: &encoded)

        XCTAssertEqual(encoded, [0x03, 0x5A, 0x00, 0x38, 0x00, 0x00, 0x00])
    }

    func testRangeValueIsEncodedUsingItsDeclaredPTPType() throws {
        XCTAssertEqual(try PTPValue.uint32(800).encode(for: .uint16), [0x20, 0x03])
    }

    func testDataPhaseDistinguishesNoDataOutgoingDataAndIncomingData() {
        XCTAssertEqual(PTPIPDataPhase.forTransaction(hasOutgoingData: false, expectsIncomingData: false), .none)
        XCTAssertEqual(PTPIPDataPhase.forTransaction(hasOutgoingData: true, expectsIncomingData: false), .outgoing)
        XCTAssertEqual(PTPIPDataPhase.forTransaction(hasOutgoingData: false, expectsIncomingData: true), .incoming)
    }

    func testDataPhaseRawValuesMatchWireProtocol() {
        XCTAssertEqual(PTPIPDataPhase.none.rawValue, 0)
        XCTAssertEqual(PTPIPDataPhase.incoming.rawValue, 1)
        XCTAssertEqual(PTPIPDataPhase.outgoing.rawValue, 2)
    }
}
