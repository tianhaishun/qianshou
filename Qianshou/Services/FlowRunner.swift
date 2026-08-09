import Foundation

/// Flow 执行引擎（App 与 CLI 共用）
///
/// 语义对齐 Maestro：tapOn/assertVisible 通过元素树文本/ID 定位，
/// swipe 用百分比坐标，所有触摸走 WDA（XCTest 注入，不碰鼠标）。
/// 断言失败即中止整个 flow 并报错（CLI 退出非零）。
@MainActor
enum FlowRunner {

    enum RunnerError: LocalizedError {
        case wdaNotRunning
        case noScreenSize
        case elementNotFound(String)
        case elementFound(String)
        case invalidSwipe(String)
        case unsupportedKey(String)
        case unsupportedSelector

        var errorDescription: String? {
            switch self {
            case .wdaNotRunning: return "WDA 未运行（scripts/start_wda.sh）"
            case .noScreenSize: return "无法获取设备屏幕尺寸"
            case .elementNotFound(let s): return "未找到元素: \(s)"
            case .elementFound(let s): return "元素不应存在但找到了: \(s)"
            case .invalidSwipe(let s): return "滑动坐标无效: \(s)"
            case .unsupportedKey(let k): return "不支持的按键: \(k)（当前支持 HOME）"
            case .unsupportedSelector: return "选择器为空"
            }
        }
    }

    /// 执行 flow 命令列表
    /// - Parameters:
    ///   - commands: 命令列表
    ///   - appId: flow header 的 appId（launchApp 用；nil 时沿用当前会话）
    ///   - onStep: 每步执行后回调（步骤索引、总数、描述）
    static func run(commands: [FlowCommand],
                    appId: String?,
                    onStep: @escaping (Int, Int, String) -> Void = { _, _, _ in }) async throws {
        try await WDAClient.shared.checkAlive()
        guard WDAClient.shared.isAlive else { throw RunnerError.wdaNotRunning }
        try await WDAClient.shared.ensureSession()

        let total = commands.count
        for (index, command) in commands.enumerated() {
            try await execute(command, appId: appId)
            onStep(index, total, describe(command))
        }
    }

    // MARK: - 命令执行

    private static func execute(_ command: FlowCommand, appId: String?) async throws {
        switch command {
        case .launchApp:
            try await WDAClient.shared.launchApp(bundleId: appId ?? "com.apple.Preferences")
            DebugLog.log("[FlowRunner] launchApp \(appId ?? "默认")")

        case .tapOn(let selector):
            guard selector.isNotEmpty else { throw RunnerError.unsupportedSelector }
            let el = try await findElement(selector)
            try await tap(el)

        case .assertVisible(let selector):
            guard selector.isNotEmpty else { throw RunnerError.unsupportedSelector }
            _ = try await findElement(selector)
            DebugLog.log("[FlowRunner] assertVisible ✓ \(selector.description)")

        case .assertNotVisible(let selector):
            guard selector.isNotEmpty else { throw RunnerError.unsupportedSelector }
            if try await findElementOptional(selector) != nil {
                throw RunnerError.elementFound(selector.description)
            }
            DebugLog.log("[FlowRunner] assertNotVisible ✓ \(selector.description)")

        case .swipe(let start, let end, let durationMs):
            guard let size = WDAClient.shared.screenSize else { throw RunnerError.noScreenSize }
            let fromX = start.x / 100 * size.width
            let fromY = start.y / 100 * size.height
            let toX = end.x / 100 * size.width
            let toY = end.y / 100 * size.height
            let duration = max(Double(durationMs ?? 500) / 1000, 0.5)
            try await WDAClient.shared.drag(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
            DebugLog.log("[FlowRunner] swipe (\(start.x)%,\(start.y)%) → (\(end.x)%,\(end.y)%) \(duration)s")

        case .inputText(let text):
            try await WDAClient.shared.typeText(text)
            DebugLog.log("[FlowRunner] inputText \"\(text)\"")

        case .pressKey(let key):
            switch key.uppercased() {
            case "HOME":
                try await WDAClient.shared.pressHome()
                DebugLog.log("[FlowRunner] pressKey HOME")
            default:
                throw RunnerError.unsupportedKey(key)
            }

        case .wait(let ms):
            DebugLog.log("[FlowRunner] wait \(ms)ms")
            try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)

        case .waitForAnimationToEnd:
            DebugLog.log("[FlowRunner] waitForAnimationToEnd")
            try await Task.sleep(nanoseconds: 500_000_000)

        case .runFlow(let whenVisible, let commands):
            if let whenVisible {
                guard whenVisible.isNotEmpty else { throw RunnerError.unsupportedSelector }
                let found = try await findElementOptional(whenVisible)
                DebugLog.log("[FlowRunner] runFlow when.visible=\(whenVisible.description) → \(found != nil ? "进入" : "跳过")")
                guard found != nil else { return }
            }
            for sub in commands {
                try await execute(sub, appId: appId)
            }
        }
    }

    // MARK: - 元素查找与点击

    /// 元素查找默认超时（页面转场动画期间轮询等待）
    static let defaultElementTimeout: TimeInterval = 10

    private static func findElement(_ selector: FlowSelector) async throws -> UIElement {
        guard let el = try await findElementOptional(selector) else {
            throw RunnerError.elementNotFound(selector.description)
        }
        return el
    }

    /// 轮询查找元素：默认每 300ms 重查元素树，直到出现或超时
    private static func findElementOptional(_ selector: FlowSelector,
                                            timeout: TimeInterval = defaultElementTimeout) async throws -> UIElement? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while true {
            let xml = try await WDAClient.shared.sourceXML()
            let elements = ElementTree.parse(xml)
            if let match = ElementTree.match(selector, in: elements) { return match }
            if ContinuousClock.now >= deadline { return nil }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private static func tap(_ el: UIElement) async throws {
        guard let size = WDAClient.shared.screenSize else { throw RunnerError.noScreenSize }
        let tx = el.centerX * size.width
        let ty = el.centerY * size.height
        DebugLog.log("[FlowRunner] tap [\(el.type)] \"\(el.label)\" @(\(tx), \(ty))")
        try await WDAClient.shared.tap(x: tx, y: ty)
    }

    // MARK: - 描述

    static func describe(_ command: FlowCommand) -> String {
        switch command {
        case .launchApp: return "启动应用"
        case .tapOn(let s): return "点击 \(s.description)"
        case .assertVisible(let s): return "断言可见 \(s.description)"
        case .assertNotVisible(let s): return "断言不可见 \(s.description)"
        case .swipe(let a, let b, _): return "滑动 (\(a.x)%,\(a.y)%)→(\(b.x)%,\(b.y)%)"
        case .inputText(let t): return "输入 \"\(t)\""
        case .pressKey(let k): return "按键 \(k)"
        case .wait(let ms): return "等待 \(ms)ms"
        case .waitForAnimationToEnd: return "等待动画结束"
        case .runFlow(let w, let c): return w != nil ? "条件流程（\(w!.description)）· \(c.count) 步" : "子流程 · \(c.count) 步"
        }
    }
}
