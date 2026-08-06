import XCTest
@testable import Qianshou

final class ClickSequenceTests: XCTestCase {

    func testSequenceJSONRoundTrip() throws {
        let seq = ClickSequence(name: "测试序列",
                                points: [
                                    SequencePoint(x: 0.5, y: 0.2, offsetMs: 300),
                                    SequencePoint(x: 0.8, y: 0.9, offsetMs: 1500),
                                ],
                                createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(seq)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClickSequence.self, from: data)

        XCTAssertEqual(decoded.name, "测试序列")
        XCTAssertEqual(decoded.points.count, 2)
        XCTAssertEqual(decoded.points[1].x, 0.8, accuracy: 0.0001)
        XCTAssertEqual(decoded.points[1].offsetMs, 1500)
        XCTAssertEqual(decoded.durationMs, 1500)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, 1_700_000_000)
    }

    func testEmptySequenceDuration() {
        let seq = ClickSequence(name: "空", points: [], createdAt: Date())
        XCTAssertEqual(seq.durationMs, 0)
    }

    func testSequenceEquality() {
        let a = ClickSequence(name: "a", points: [SequencePoint(x: 0.1, y: 0.1, offsetMs: 10)], createdAt: Date())
        var b = a
        XCTAssertEqual(a, b)
        b.points[0].offsetMs = 999
        XCTAssertNotEqual(a, b)
    }
}
