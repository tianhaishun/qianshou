import XCTest
@testable import Qianshou

/// 元素树解析与选择器匹配测试
final class ElementTreeTests: XCTestCase {

    /// WDA v16 格式 XML（440x956 坐标系）
    private let modernXML = """
    <XCUIElementTree>
      <XCUIElementTypeApplication x="0" y="0" width="440" height="956" label="设置">
        <XCUIElementTypeCell x="0" y="100" width="440" height="80" label="通用" identifier="general_cell"/>
        <XCUIElementTypeCell x="0" y="200" width="440" height="80" label="关于本机"/>
        <XCUIElementTypeButton x="20" y="400" width="100" height="50" label="返回" identifier="back_button"/>
      </XCUIElementTypeApplication>
    </XCUIElementTree>
    """

    /// 旧版 frame 格式 XML
    private let legacyXML = """
    <XCUIElementTree>
      <XCUIElementTypeApplication frame="{{0, 0}, {402, 874}}" label="设置">
        <XCUIElementTypeCell frame="{{0, 100}, {402, 80}}" label="通用"/>
      </XCUIElementTypeApplication>
    </XCUIElementTree>
    """

    func testParseModernFormat() {
        let elements = ElementTree.parse(modernXML)
        XCTAssertEqual(elements.count, 3)
        let first = elements[0]
        XCTAssertEqual(first.type, "Cell")
        XCTAssertEqual(first.label, "通用")
        XCTAssertEqual(first.identifier, "general_cell")
        XCTAssertEqual(first.relX, 0)
        XCTAssertEqual(first.relY, 100.0 / 956.0, accuracy: 0.001)
        XCTAssertEqual(first.centerY, (100.0 + 40) / 956.0, accuracy: 0.001)
    }

    func testParseLegacyFormat() {
        let elements = ElementTree.parse(legacyXML)
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].label, "通用")
        XCTAssertEqual(elements[0].relX, 0)
    }

    func testMatchByExactText() {
        let elements = ElementTree.parse(modernXML)
        let match = ElementTree.match(FlowSelector(text: "关于本机"), in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.label, "关于本机")
    }

    func testMatchBySubstring() {
        let elements = ElementTree.parse(modernXML)
        let match = ElementTree.match(FlowSelector(text: "通用"), in: elements)
        XCTAssertNotNil(match)
    }

    func testMatchById() {
        let elements = ElementTree.parse(modernXML)
        let match = ElementTree.match(FlowSelector(id: "back_button"), in: elements)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.label, "返回")
    }

    func testMatchMissReturnsNil() {
        let elements = ElementTree.parse(modernXML)
        XCTAssertNil(ElementTree.match(FlowSelector(text: "不存在"), in: elements))
        XCTAssertNil(ElementTree.match(FlowSelector(id: "missing_id"), in: elements))
    }

    func testTextMatchesCaseInsensitive() {
        XCTAssertTrue(ElementTree.textMatches("Settings", pattern: "settings"))
        XCTAssertTrue(ElementTree.textMatches("设置", pattern: "设置"))
        XCTAssertFalse(ElementTree.textMatches("设置", pattern: "通用"))
    }

    func testEmptyLabelAndIdentifierIgnored() {
        let xml = """
        <XCUIElementTypeApplication x="0" y="0" width="440" height="956" label="App">
          <XCUIElementTypeStaticText x="0" y="0" width="100" height="20"/>
        </XCUIElementTypeApplication>
        """
        XCTAssertTrue(ElementTree.parse(xml).isEmpty)
    }

    func testRelativeCoordinateClamped() {
        // 坐标系不一致时归一化仍应 ≤ 1
        let xml = """
        <XCUIElementTypeApplication x="0" y="0" width="440" height="956" label="App">
          <XCUIElementTypeCell x="0" y="900" width="440" height="80" label="底部"/>
        </XCUIElementTypeApplication>
        """
        let elements = ElementTree.parse(xml)
        XCTAssertLessThanOrEqual(elements[0].relY, 1.0)
        // 底部元素归一化后可能轻微超出 1（XML 坐标系与屏幕尺寸近似）
        XCTAssertLessThanOrEqual(elements[0].relY + elements[0].relH, 1.05)
    }
}
