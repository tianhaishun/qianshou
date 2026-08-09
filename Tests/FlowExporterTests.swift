import XCTest
@testable import Qianshou

/// FlowExporter：AI 动作序列 → YAML flow（roundtrip 自洽验证）
final class FlowExporterTests: XCTestCase {

    /// 导出 → 解析 → 命令，验证语义完整
    private func assertRoundtrip(_ actions: [FlowExporter.Action], expect: [FlowCommand]) throws {
        let yaml = FlowExporter.yaml(from: actions)
        let document = try YAMLParser.parse(yaml)
        let commands = try FlowParser.parse(document).commands
        XCTAssertEqual(commands, expect, "导出脚本应可解析回等价的命令\n\(yaml)")
    }

    func testElementTapExportsTextSelector() throws {
        try assertRoundtrip(
            [.tapElement(label: "通用")],
            expect: [.tapOn(FlowSelector(text: "通用"))]
        )
    }

    func testPointTapExportsPercent() throws {
        try assertRoundtrip(
            [.tapPoint(xPct: 50, yPct: 30)],
            expect: [.tapOn(FlowSelector(point: FlowPercentPoint(x: 50, y: 30)))]
        )
    }

    func testTypeExportsInputText() throws {
        try assertRoundtrip(
            [.type(text: "hello")],
            expect: [.inputText("hello")]
        )
    }

    func testSwipeExportsPercent() throws {
        try assertRoundtrip(
            [.swipe(fxPct: 50, fyPct: 80, txPct: 50, tyPct: 10)],
            expect: [.swipe(
                start: FlowPercentPoint(x: 50, y: 80),
                end: FlowPercentPoint(x: 50, y: 10),
                durationMs: nil
            )]
        )
    }

    func testPressHomeExportsKey() throws {
        try assertRoundtrip(
            [.pressHome],
            expect: [.pressKey("HOME")]
        )
    }

    func testMixedSequenceRoundtrip() throws {
        try assertRoundtrip(
            [
                .tapElement(label: "设置"),
                .tapElement(label: "通用"),
                .tapPoint(xPct: 50, yPct: 50),
                .type(text: "hello"),
                .swipe(fxPct: 50, fyPct: 80, txPct: 50, tyPct: 20),
                .pressHome,
            ],
            expect: [
                .tapOn(FlowSelector(text: "设置")),
                .tapOn(FlowSelector(text: "通用")),
                .tapOn(FlowSelector(point: FlowPercentPoint(x: 50, y: 50))),
                .inputText("hello"),
                .swipe(
                    start: FlowPercentPoint(x: 50, y: 80),
                    end: FlowPercentPoint(x: 50, y: 20),
                    durationMs: nil
                ),
                .pressKey("HOME"),
            ]
        )
    }

    func testEmptySequence() {
        XCTAssertEqual(FlowExporter.yaml(from: []), "")
    }

    func testLabelWithQuotesEscaped() throws {
        // label 含引号/冒号时转义后仍可解析
        let yaml = FlowExporter.yaml(from: [.tapElement(label: "a\"b:c")])
        XCTAssertTrue(yaml.contains("\\\""), "引号应转义: \(yaml)")
        let document = try YAMLParser.parse(yaml)
        let commands = try FlowParser.parse(document).commands
        XCTAssertEqual(commands, [.tapOn(FlowSelector(text: "a\"b:c"))])
    }

    func testEscapeHandlesControlChars() {
        XCTAssertEqual(FlowExporter.escape("a\"b\\c\nd\t"), "a\\\"b\\\\c\\nd\\t")
    }

    func testYAMLHeaderPresent() {
        let yaml = FlowExporter.yaml(from: [.pressHome])
        XCTAssertTrue(yaml.contains("---"))
        XCTAssertTrue(yaml.contains("由千手 AI 生成"))
    }
}
