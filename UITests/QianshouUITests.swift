import XCTest

/// 千手 UI 测试：启动、模式切换、配置弹出
/// 依赖无障碍标签（各视图已加 accessibilityLabel）
final class QianshouUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        _ = app.windows.firstMatch.waitForExistence(timeout: 5)
        // macOS 上 click 需要 key window：显式激活
        app.activate()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 启动后：品牌头、设备菜单、底部条、配置入口存在
    func testLaunchShowsCoreUI() {
        XCTAssertTrue(app.staticTexts["千手"].exists, "品牌标题应存在")
        XCTAssertTrue(app.menuButtons["选择模拟器设备"].waitForExistence(timeout: 10), "设备菜单应存在")
        XCTAssertTrue(app.buttons["开始连点"].exists, "连点模式底部条主按钮应存在")
        XCTAssertTrue(app.buttons["打开配置"].exists, "配置入口应存在")
    }

    /// 点击工具栏「录制」按钮切换到录制模式
    func testSwitchToRecorderMode() {
        let recordTab = app.buttons["切换到录制模式"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 3), "录制模式按钮应存在")
        recordTab.click()
        XCTAssertTrue(app.buttons["开始录制"].waitForExistence(timeout: 3), "录制模式应显示开始录制按钮")
    }

    /// 切回连点模式
    func testSwitchBackToClickerMode() {
        app.buttons["切换到录制模式"].click()
        XCTAssertTrue(app.buttons["开始录制"].waitForExistence(timeout: 3))
        app.buttons["切换到连点模式"].click()
        XCTAssertTrue(app.buttons["开始连点"].waitForExistence(timeout: 3), "应切回连点模式")
    }

    /// ⚙ 配置弹出层：连点模式显示点位与时序配置
    func testConfigPopoverClickerMode() {
        let gear = app.buttons["打开配置"]
        XCTAssertTrue(gear.exists)
        gear.click()
        XCTAssertTrue(app.staticTexts["连点配置"].waitForExistence(timeout: 3), "配置弹出层应显示标题")
        XCTAssertTrue(app.staticTexts["点位"].exists)
        XCTAssertTrue(app.staticTexts["时序"].exists)
    }

    /// ⚙ 配置弹出层：录制模式显示序列管理
    func testConfigPopoverRecorderMode() {
        app.buttons["切换到录制模式"].click()
        XCTAssertTrue(app.buttons["开始录制"].waitForExistence(timeout: 3))
        app.buttons["打开配置"].click()
        XCTAssertTrue(app.staticTexts["录制与序列"].waitForExistence(timeout: 3), "录制模式配置标题应正确")
        XCTAssertTrue(app.staticTexts["已保存序列"].exists)
    }

    /// 无点位时主按钮禁用
    func testStartButtonDisabledWithoutPoints() {
        let start = app.buttons["开始连点"]
        XCTAssertFalse(start.isEnabled, "无点位时开始连点应禁用")
    }
}
