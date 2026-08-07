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

    func testDragPointJSONRoundTrip() throws {
        let seq = ClickSequence(name: "拖动序列",
                                points: [
                                    SequencePoint(kind: .drag, x: 0.2, y: 0.3, offsetMs: 500,
                                                  endX: 0.8, endY: 0.9, durationMs: 400),
                                ],
                                createdAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(seq)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClickSequence.self, from: data)

        let p = decoded.points[0]
        XCTAssertEqual(p.kind, .drag)
        XCTAssertEqual(p.endX ?? 0, 0.8, accuracy: 0.0001)
        XCTAssertEqual(p.endY ?? 0, 0.9, accuracy: 0.0001)
        XCTAssertEqual(p.durationMs ?? 0, 400)
    }

    func testOldJSONWithoutNewFieldsDecodes() throws {
        // 模拟旧版本保存的 JSON（无 kind/endX/endY/durationMs 字段）
        let oldJSON = """
        [{"x":0.5,"y":0.5,"offsetMs":100}]
        """
        let data = try XCTUnwrap(oldJSON.data(using: .utf8))
        struct Wrapper: Decodable { let points: [SequencePoint] }
        // 用 ClickSequence 的编码容器不可行，直接测 SequencePoint 解码
        let points = try JSONDecoder().decode([SequencePoint].self, from: data)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].kind, .click)
        XCTAssertEqual(points[0].x, 0.5, accuracy: 0.0001)
    }

    func testDragJSONMissingFieldsDecodes() throws {
        // drag 点缺 endX/endY/durationMs 时仍可解码（回放退化为原地点击）
        let json = """
        [{"kind":"drag","x":0.1,"y":0.2,"offsetMs":300}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let points = try JSONDecoder().decode([SequencePoint].self, from: data)
        XCTAssertEqual(points[0].kind, .drag)
        XCTAssertNil(points[0].endX)
        XCTAssertNil(points[0].durationMs)
    }

    func testUnknownKindFallsBackToClick() throws {
        // 未知 kind 值回退 .click，而不是整个序列解码失败
        let json = """
        [{"kind":"pinch","x":0.1,"y":0.2,"offsetMs":300}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let points = try JSONDecoder().decode([SequencePoint].self, from: data)
        XCTAssertEqual(points[0].kind, .click)
    }

    func testDurationIncludesDrag() {
        let seq = ClickSequence(name: "含拖拽",
                                points: [
                                    SequencePoint(x: 0, y: 0, offsetMs: 100),
                                    SequencePoint(kind: .drag, x: 0, y: 0, offsetMs: 500,
                                                  endX: 1, endY: 1, durationMs: 800),
                                ],
                                createdAt: Date())
        // 拖拽结束时间 = 500 + 800，而非 500
        XCTAssertEqual(seq.durationMs, 1300)
    }

    func testSequenceEquality() {
        let a = ClickSequence(name: "a", points: [SequencePoint(x: 0.1, y: 0.1, offsetMs: 10)], createdAt: Date())
        var b = a
        XCTAssertEqual(a, b)
        b.points[0].offsetMs = 999
        XCTAssertNotEqual(a, b)
    }
}
