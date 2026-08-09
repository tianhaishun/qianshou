import Foundation

/// Flow 脚本模型 —— YAML 命令子集
///
/// 支持命令：launchApp / tapOn / assertVisible / assertNotVisible /
/// swipe / inputText / pressKey / wait / waitForAnimationToEnd / runFlow。
/// 语法是移动自动化领域的通用惯例（元素文本定位 + 断言 + 条件子流程）。
///
/// 示例:
/// ```yaml
/// appId: com.apple.Preferences
/// ---
/// - launchApp
/// - tapOn: "通用"
/// - assertVisible: "关于本机"
/// ```

/// 元素选择器（text / id / point 三选一，text 支持精确/子串/正则）
struct FlowSelector: Equatable {
    var text: String?
    var id: String?
    /// 坐标定位（"50%, 50%"）—— 不依赖元素树，直接点击
    var point: FlowPercentPoint?

    var isNotEmpty: Bool { text != nil || id != nil || point != nil }

    var description: String {
        if let text { return "text=\(text)" }
        if let id { return "id=\(id)" }
        if let point { return "point=\(Int(point.x))%,\(Int(point.y))%" }
        return "(空选择器)"
    }
}

/// 百分比点（"50%, 50%"）—— 相对屏幕坐标
struct FlowPercentPoint: Equatable {
    let x: Double  // 0-100
    let y: Double

    /// 解析 "50%, 50%" 格式；失败返回 nil
    static func parse(_ raw: String) -> FlowPercentPoint? {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = parsePercent(parts[0]),
              let y = parsePercent(parts[1]) else { return nil }
        return FlowPercentPoint(x: x, y: y)
    }

    private static func parsePercent(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: "%", with: "")
        guard let v = Double(cleaned) else { return nil }
        return v
    }
}

/// Flow 命令
indirect enum FlowCommand: Equatable {
    /// 启动 app（bundleId 来自 flow header 的 appId；缺省用当前会话）
    case launchApp
    /// 点击匹配元素
    case tapOn(FlowSelector)
    /// 断言元素存在（失败 → 整个 flow 失败）
    case assertVisible(FlowSelector)
    /// 断言元素不存在
    case assertNotVisible(FlowSelector)
    /// 滑动（百分比坐标）
    case swipe(start: FlowPercentPoint, end: FlowPercentPoint, durationMs: Int?)
    /// 输入文本（输入框需已聚焦）
    case inputText(String)
    /// 按键（当前支持 HOME）
    case pressKey(String)
    /// 固定等待
    case wait(ms: Int)
    /// 等待动画结束（简化：固定 500ms）
    case waitForAnimationToEnd
    /// 条件子流程（when.visible 匹配才执行）
    case runFlow(whenVisible: FlowSelector?, commands: [FlowCommand])
}

// MARK: - YAML → Flow

enum FlowError: LocalizedError {
    case parse(String)
    case unsupportedCommand(String)
    case missingValue(String)
    case invalidSelector(String)

    var errorDescription: String? {
        switch self {
        case .parse(let m): return "Flow 解析失败: \(m)"
        case .unsupportedCommand(let c): return "不支持的命令: \(c)"
        case .missingValue(let c): return "命令缺少参数: \(c)"
        case .invalidSelector(let m): return "选择器无效: \(m)"
        }
    }
}

/// 把 YAML 解析树构建为 [FlowCommand]
enum FlowParser {

    static func parse(_ document: YAMLParser.Document) throws -> (appId: String?, commands: [FlowCommand]) {
        let appId = document.header["appId"]?.stringValue
        guard case .list(let items) = document.root else {
            throw FlowError.parse("flow 顶层必须是命令列表")
        }
        return (appId, try items.map(command))
    }

    /// 单项 → 命令：裸标量 = 命令名；map = 命令名 + 参数
    static func command(_ value: YAMLParser.Value) throws -> FlowCommand {
        switch value {
        case .string(let name):
            return try bareCommand(name)
        case .map(let m):
            guard let (name, params) = m.first else { throw FlowError.parse("空命令") }
            return try commandWithParams(name, params)
        default:
            throw FlowError.parse("无法识别的命令: \(value)")
        }
    }

    // MARK: 无参命令

    private static func bareCommand(_ name: String) throws -> FlowCommand {
        switch name {
        case "launchApp": return .launchApp
        case "waitForAnimationToEnd": return .waitForAnimationToEnd
        default: throw FlowError.unsupportedCommand(name)
        }
    }

    // MARK: 带参命令

    private static func commandWithParams(_ name: String, _ params: YAMLParser.Value) throws -> FlowCommand {
        switch name {
        case "tapOn":
            return .tapOn(try selector(params, command: name))
        case "assertVisible":
            return .assertVisible(try selector(params, command: name))
        case "assertNotVisible":
            return .assertNotVisible(try selector(params, command: name))
        case "swipe":
            return try swipeCommand(params)
        case "inputText":
            guard let s = params.stringValue, !s.isEmpty else { throw FlowError.missingValue("inputText") }
            return .inputText(s)
        case "pressKey":
            guard let s = params.stringValue else { throw FlowError.missingValue("pressKey") }
            return .pressKey(s)
        case "wait":
            guard case .map(let m) = params, let msValue = m["ms"] else {
                throw FlowError.missingValue("wait.ms")
            }
            let ms: Int
            if let s = msValue.stringValue, let v = Int(s) {
                ms = v
            } else if case .number(let n) = msValue {
                ms = Int(n)
            } else {
                throw FlowError.missingValue("wait.ms")
            }
            return .wait(ms: ms)
        case "waitForAnimationToEnd":
            return .waitForAnimationToEnd
        case "runFlow":
            return try runFlowCommand(params)
        default:
            throw FlowError.unsupportedCommand(name)
        }
    }

    private static func selector(_ params: YAMLParser.Value, command: String) throws -> FlowSelector {
        switch params {
        case .string(let s):
            return FlowSelector(text: s)
        case .map(let m):
            let text = m["text"]?.stringValue
            let id = m["id"]?.stringValue
            var point: FlowPercentPoint?
            if let pointRaw = m["point"]?.stringValue {
                guard let parsed = FlowPercentPoint.parse(pointRaw) else {
                    throw FlowError.invalidSelector("point 格式无效: \(pointRaw)（应为 \"50%, 50%\"）")
                }
                point = parsed
            }
            let selector = FlowSelector(text: text, id: id, point: point)
            guard selector.isNotEmpty else { throw FlowError.invalidSelector("\(command) 需要 text / id / point") }
            return selector
        default:
            throw FlowError.invalidSelector("\(command) 需要字符串或 text/id/point 映射")
        }
    }

    private static func swipeCommand(_ params: YAMLParser.Value) throws -> FlowCommand {
        guard case .map(let m) = params,
              let startRaw = m["start"]?.stringValue,
              let endRaw = m["end"]?.stringValue,
              let start = FlowPercentPoint.parse(startRaw),
              let end = FlowPercentPoint.parse(endRaw) else {
            throw FlowError.missingValue("swipe.start/end（格式 \"50%, 50%\"）")
        }
        let duration = m["duration"].flatMap { value -> Int? in
            if let d = value.stringValue { return Int(d) }
            if case .number(let n) = value { return Int(n) }
            return nil
        }
        return .swipe(start: start, end: end, durationMs: duration)
    }

    private static func runFlowCommand(_ params: YAMLParser.Value) throws -> FlowCommand {
        guard case .map(let m) = params else { throw FlowError.missingValue("runFlow") }
        var whenSelector: FlowSelector?
        if case .map(let when) = m["when"], let visible = when["visible"] {
            whenSelector = try selector(visible, command: "runFlow.when.visible")
        }
        var commands: [FlowCommand] = []
        if case .list(let items) = m["commands"] {
            commands = try items.map(command)
        }
        return .runFlow(whenVisible: whenSelector, commands: commands)
    }
}
