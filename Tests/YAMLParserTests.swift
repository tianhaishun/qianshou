import XCTest
@testable import Qianshou

/// YAML 子集解析器测试（Maestro flow 兼容子集）
final class YAMLParserTests: XCTestCase {

    private func parseFlow(_ yaml: String) throws -> [YAMLParser.Value] {
        let doc = try YAMLParser.parse(yaml)
        guard case .list(let cmds) = doc.root else {
            XCTFail("root 应为 list，实际: \(doc.root)")
            return []
        }
        return cmds
    }

    func testHeaderAndSeparator() throws {
        let doc = try YAMLParser.parse("""
        appId: com.apple.Preferences
        ---
        - launchApp
        """)
        XCTAssertEqual(doc.header["appId"], .string("com.apple.Preferences"))
        let cmds = try parseFlow("""
        appId: com.apple.Preferences
        ---
        - launchApp
        """)
        XCTAssertEqual(cmds.count, 1)
    }

    func testNoSeparatorMeansNoHeader() throws {
        let cmds = try parseFlow("- launchApp\n- assertVisible: x")
        XCTAssertEqual(cmds.count, 2)
        XCTAssertEqual(cmds[0], .string("launchApp"))
        XCTAssertEqual(cmds[1], .map(["assertVisible": .string("x")]))
    }

    func testBareCommandIsScalar() throws {
        let cmds = try parseFlow("- launchApp")
        XCTAssertEqual(cmds[0], .string("launchApp"))
    }

    func testStringShorthand() throws {
        let cmds = try parseFlow("- tapOn: \"通用\"")
        XCTAssertEqual(cmds[0], .map(["tapOn": .string("通用")]))
    }

    func testNestedMapCommand() throws {
        let cmds = try parseFlow("""
        - tapOn:
            text: "关于本机"
            index: 1
        """)
        XCTAssertEqual(cmds[0], .map(["tapOn": .map([
            "text": .string("关于本机"),
            "index": .number(1),
        ])]))
    }

    func testMultiKeyNestedMap() throws {
        let cmds = try parseFlow("""
        - swipe:
            start: 50%, 50%
            end: 50%, 10%
        """)
        XCTAssertEqual(cmds[0], .map(["swipe": .map([
            "start": .string("50%, 50%"),
            "end": .string("50%, 10%"),
        ])]))
    }

    func testNumberAndBoolScalars() throws {
        let cmds = try parseFlow("""
        - wait:
            ms: 1000
        - assertVisible:
            enabled: true
        """)
        XCTAssertEqual(cmds[0], .map(["wait": .map(["ms": .number(1000)])]))
        XCTAssertEqual(cmds[1], .map(["assertVisible": .map(["enabled": .bool(true)])]))
    }

    func testCommentsAndBlankLines() throws {
        let cmds = try parseFlow("# 仅注释\n\n- tapOn: a # 行内注释")
        XCTAssertEqual(cmds.count, 1)
        XCTAssertEqual(cmds[0], .map(["tapOn": .string("a")]))
    }

    func testQuotedStringWithSpaces() throws {
        let cmds = try parseFlow("- tapOn: \"带 空格 的\"")
        XCTAssertEqual(cmds[0], .map(["tapOn": .string("带 空格 的")]))
    }

    func testRunFlowNested() throws {
        let cmds = try parseFlow("""
        - runFlow:
            when:
              visible: "设置"
            commands:
              - tapOn: "通用"
        """)
        guard case .map(let m) = cmds[0],
              case .map(let rf) = m["runFlow"],
              case .map(let when) = rf["when"],
              case .list(let inner) = rf["commands"] else {
            XCTFail("runFlow 结构不符: \(cmds[0])")
            return
        }
        XCTAssertEqual(when["visible"], .string("设置"))
        XCTAssertEqual(inner.count, 1)
    }

    func testQuotedColonNotTreatedAsKey() throws {
        // 冒号后无空格的字符串（URL 等）不应被当作 key
        let cmds = try parseFlow("- inputText: https://example.com")
        XCTAssertEqual(cmds[0], .map(["inputText": .string("https://example.com")]))
    }

    func testEmptyValueIsNull() throws {
        let cmds = try parseFlow("- launchApp:")
        XCTAssertEqual(cmds[0], .map(["launchApp": .null]))
    }
}
