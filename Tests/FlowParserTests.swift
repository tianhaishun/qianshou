import XCTest
@testable import Qianshou

/// FlowParser：YAML → FlowCommand 构建测试
final class FlowParserTests: XCTestCase {

    private func parseCommands(_ yaml: String) throws -> [FlowCommand] {
        let doc = try YAMLParser.parse(yaml)
        return try FlowParser.parse(doc).commands
    }

    func testLaunchAppBare() throws {
        let cmds = try parseCommands("- launchApp")
        XCTAssertEqual(cmds, [.launchApp])
    }

    func testTapOnStringShorthand() throws {
        let cmds = try parseCommands("- tapOn: \"通用\"")
        XCTAssertEqual(cmds, [.tapOn(FlowSelector(text: "通用"))])
    }

    func testTapOnTextAndIdMap() throws {
        let cmds = try parseCommands("""
        - tapOn:
            text: "关于本机"
            id: com.example.about
        """)
        XCTAssertEqual(cmds, [.tapOn(FlowSelector(text: "关于本机", id: "com.example.about"))])
    }

    func testAssertVisibleAndNot() throws {
        let cmds = try parseCommands("""
        - assertVisible: "设置"
        - assertNotVisible: "加载中"
        """)
        XCTAssertEqual(cmds, [
            .assertVisible(FlowSelector(text: "设置")),
            .assertNotVisible(FlowSelector(text: "加载中")),
        ])
    }

    func testSwipeWithPercentages() throws {
        let cmds = try parseCommands("""
        - swipe:
            start: 50%, 50%
            end: 50%, 10%
        """)
        XCTAssertEqual(cmds, [.swipe(
            start: FlowPercentPoint(x: 50, y: 50),
            end: FlowPercentPoint(x: 50, y: 10),
            durationMs: nil
        )])
    }

    func testSwipeWithDuration() throws {
        let cmds = try parseCommands("""
        - swipe:
            start: 10%, 80%
            end: 90%, 80%
            duration: 1200
        """)
        XCTAssertEqual(cmds, [.swipe(
            start: FlowPercentPoint(x: 10, y: 80),
            end: FlowPercentPoint(x: 90, y: 80),
            durationMs: 1200
        )])
    }

    func testInputTextAndPressKey() throws {
        let cmds = try parseCommands("""
        - inputText: "hello"
        - pressKey: HOME
        """)
        XCTAssertEqual(cmds, [.inputText("hello"), .pressKey("HOME")])
    }

    func testWait() throws {
        let cmds = try parseCommands("- wait:\n    ms: 1500")
        XCTAssertEqual(cmds, [.wait(ms: 1500)])
    }

    func testRunFlowWithWhen() throws {
        let cmds = try parseCommands("""
        - runFlow:
            when:
              visible: "设置"
            commands:
              - tapOn: "通用"
              - assertVisible: "关于本机"
        """)
        XCTAssertEqual(cmds, [.runFlow(
            whenVisible: FlowSelector(text: "设置"),
            commands: [
                .tapOn(FlowSelector(text: "通用")),
                .assertVisible(FlowSelector(text: "关于本机")),
            ]
        )])
    }

    func testAppIdFromHeader() throws {
        let doc = try YAMLParser.parse("""
        appId: com.apple.Preferences
        ---
        - launchApp
        """)
        let (appId, _) = try FlowParser.parse(doc)
        XCTAssertEqual(appId, "com.apple.Preferences")
    }

    func testUnsupportedCommandThrows() {
        XCTAssertThrowsError(try parseCommands("- madeUpCommand: x")) { error in
            guard case FlowError.unsupportedCommand(let name) = error else {
                return XCTFail("应为 unsupportedCommand: \(error)")
            }
            XCTAssertEqual(name, "madeUpCommand")
        }
    }

    func testEmptySelectorThrows() {
        XCTAssertThrowsError(try parseCommands("- tapOn:\n    enabled: true"))
    }

    func testPercentPointParsing() {
        XCTAssertEqual(FlowPercentPoint.parse("50%, 50%"), FlowPercentPoint(x: 50, y: 50))
        XCTAssertEqual(FlowPercentPoint.parse("0%, 100%"), FlowPercentPoint(x: 0, y: 100))
        XCTAssertNil(FlowPercentPoint.parse("50"))
        XCTAssertNil(FlowPercentPoint.parse("a%, b%"))
    }
}
