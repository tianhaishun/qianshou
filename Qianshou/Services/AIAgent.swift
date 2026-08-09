import ImageIO
import Foundation

/// AI 驾驶模式：自然语言目标 → 自主操作模拟器
///
/// 循环：截屏 + 元素树 → Claude 视觉+语义决策 → WDA 执行工具 → 再看屏幕，
/// 直到任务完成（finish）或需要用户确认（ask_user）或超过最大步数。
@MainActor
final class AIAgent: ObservableObject {

    struct Step: Identifiable {
        let id = UUID()
        let summary: String
        let detail: String?
        let isAction: Bool
        let timestamp = Date()
    }

    @Published private(set) var isRunning = false

    /// 是否已有可用凭据（API Key 或 OAuth Token）
    var hasCredentials: Bool { !client.apiKey.isEmpty || !client.oauthToken.isEmpty }
    @Published private(set) var steps: [Step] = []
    @Published private(set) var lastScreenshot: String?   // base64
    @Published var pendingQuestion: String?
    @Published var finalSummary: String?

    private let client = AnthropicClient()
    private var messages: [AnthropicClient.Message] = []
    private var task: Task<Void, Never>?

    /// 配置凭据与模型（支持 API Key / OAuth Token —— 本地自动探测）
    func configure(apiKey: String = "", oauthToken: String = "", baseURL: String = "", model: String = "claude-opus-4-8") {
        client.apiKey = apiKey
        client.oauthToken = oauthToken
        client.baseURL = baseURL
        client.model = model
    }

    /// 开始执行任务（自然语言目标；凭据已在 configure 配置）
    func run(goal: String) {
        guard !isRunning, hasCredentials else { return }

        isRunning = true
        finalSummary = nil
        pendingQuestion = nil
        steps = []
        messages = [
            AnthropicClient.Message(role: "user", content: [.text(goal)]),
        ]

        task = Task { [weak self] in
            await self?.loop()
            self?.isRunning = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        addStep("已停止", detail: nil, isAction: false)
    }

    /// 回答 ask_user 的问题后继续
    func answer(_ answer: String) {
        pendingQuestion = nil
        guard !isRunning else { return }
        // 将回答作为用户消息继续循环
        messages.append(AnthropicClient.Message(role: "user", content: [.text(answer)]))
        task = Task { [weak self] in
            await self?.loop()
            self?.isRunning = false
        }
        isRunning = true
    }

    /// 手动补充模式：运行中随时插入指令（中断当前决策，从补充处继续）
    func supplement(_ instruction: String) {
        task?.cancel()
        task = nil
        messages.append(AnthropicClient.Message(
            role: "user",
            content: [.text("[用户补充指令] \(instruction)（请据此调整执行）")]
        ))
        task = Task { [weak self] in
            await self?.loop()
            self?.isRunning = false
        }
    }

    private func addStep(_ summary: String, detail: String?, isAction: Bool) {
        steps.append(Step(summary: summary, detail: detail, isAction: isAction))
    }

    // MARK: - 循环

    private let systemPrompt = """
    你是 iOS 模拟器操作 Agent。你的任务是根据用户的目标，通过观察屏幕并执行触摸操作来完成。

    工作方式：
    1. 每次决策你会收到：当前屏幕截图 + 可交互元素列表（带编号）
    2. 观察截图与元素，选择最合适的工具执行一步
    3. 执行后你会看到新的屏幕状态，继续下一步直到任务完成

    规则：
    - 优先用 tap_element 点击有明确编号的元素；元素不可靠时用 tap 坐标
    - 输入文本前通常需要先 tap 聚焦输入框
    - 滚动列表用 swipe
    - 任务完成时调用 finish 并简述结果
    - 遇到需要用户决定的事（如登录账号密码、删除确认）调用 ask_user
    - 最多 30 步；卡住时（连续 3 步无变化）调用 finish 说明卡住原因
    - 坐标单位是设备逻辑像素（iPhone 17 Pro 为 402x874）
    """

    private let tools: [AnthropicClient.ToolDef] = [
        AnthropicClient.ToolDef(
            name: "tap_element",
            description: "点击元素列表中的指定编号元素。元素编号来自观察列表。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "index": AnthropicClient.AnyCodable(["type": "integer", "description": "元素编号"]),
                ]),
                "required": AnthropicClient.AnyCodable(["index"]),
            ]
        ),
        AnthropicClient.ToolDef(
            name: "tap",
            description: "在屏幕坐标 (x, y) 处点击。坐标单位是设备逻辑像素。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "x": AnthropicClient.AnyCodable(["type": "number", "description": "x 坐标"]),
                    "y": AnthropicClient.AnyCodable(["type": "number", "description": "y 坐标"]),
                ]),
                "required": AnthropicClient.AnyCodable(["x", "y"]),
            ]
        ),
        AnthropicClient.ToolDef(
            name: "type",
            description: "向当前聚焦的输入框输入文本（模拟键盘）。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "text": AnthropicClient.AnyCodable(["type": "string", "description": "要输入的文本"]),
                ]),
                "required": AnthropicClient.AnyCodable(["text"]),
            ]
        ),
        AnthropicClient.ToolDef(
            name: "swipe",
            description: "从起点滑动到终点（滚动列表常用）。坐标是设备逻辑像素。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "from_x": AnthropicClient.AnyCodable(["type": "number"]),
                    "from_y": AnthropicClient.AnyCodable(["type": "number"]),
                    "to_x": AnthropicClient.AnyCodable(["type": "number"]),
                    "to_y": AnthropicClient.AnyCodable(["type": "number"]),
                ]),
                "required": AnthropicClient.AnyCodable(["from_x", "from_y", "to_x", "to_y"]),
            ]
        ),
        AnthropicClient.ToolDef(
            name: "press_home",
            description: "回到主屏幕。",
            inputSchema: ["type": AnthropicClient.AnyCodable("object"), "properties": AnthropicClient.AnyCodable([:])]
        ),
        AnthropicClient.ToolDef(
            name: "finish",
            description: "任务完成或无法继续时调用，附上结果说明。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "summary": AnthropicClient.AnyCodable(["type": "string", "description": "结果总结"]),
                ]),
                "required": AnthropicClient.AnyCodable(["summary"]),
            ]
        ),
        AnthropicClient.ToolDef(
            name: "ask_user",
            description: "需要用户提供信息或确认时调用（如登录凭据、危险操作确认）。",
            inputSchema: [
                "type": AnthropicClient.AnyCodable("object"),
                "properties": AnthropicClient.AnyCodable([
                    "question": AnthropicClient.AnyCodable(["type": "string", "description": "要问用户的问题"]),
                ]),
                "required": AnthropicClient.AnyCodable(["question"]),
            ]
        ),
    ]

    private func loop() async {
        var noChangeCount = 0
        for step in 0..<30 {
            guard !Task.isCancelled else { return }
            guard let current = await observe() else {
                addStep("观察屏幕失败", detail: nil, isAction: false)
                return
            }

            // 组装本轮消息（截图 + 元素 + 用户消息历史）
            let userContent: [AnthropicClient.ContentBlock] = [
                .image(base64: current.screenshot),
                .text("当前屏幕元素列表（编号 0 起）:\n\(current.elements)\n\n请决定下一步操作。"),
            ]
            let userMsg = AnthropicClient.Message(role: "user", content: userContent)

            DebugLog.log("[AIAgent] 步骤 \(step+1)/30：观察完成 \(current.elements.split(separator: "\n").count) 元素，请求 Claude")
            let response: AnthropicClient.ChatResponse
            do {
                response = try await client.chat(
                    system: systemPrompt,
                    messages: messages + [userMsg],
                    tools: tools
                )
            } catch {
                // 手动补充/停止会取消当前请求 —— 静默退出，不报错
                if Task.isCancelled { return }
                DebugLog.log("[AIAgent] API 失败(第 1 次): \(error.localizedDescription)，重试...")
                // 网络类错误重试一次（TLS/超时）
                do {
                    response = try await client.chat(
                        system: systemPrompt,
                        messages: messages + [userMsg],
                        tools: tools
                    )
                } catch {
                    if Task.isCancelled { return }
                    DebugLog.log("[AIAgent] API 失败(第 2 次): \(error.localizedDescription)")
                    addStep("AI 请求失败", detail: error.localizedDescription, isAction: false)
                    return
                }
            }

            // 追加 assistant 回合
            messages.append(AnthropicClient.Message(role: "assistant", content: response.content))

            // 提取工具调用
            let toolUses = response.content.compactMap { block -> AnthropicClient.ContentBlock? in
                if case .toolUse = block { return block }
                return nil
            }

            if toolUses.isEmpty {
                // 无工具调用：直接结束
                let text = response.content.compactMap { block -> String? in
                    if case .text(let t) = block { return t }
                    return nil
                }.joined()
                finalSummary = text.isEmpty ? "任务结束" : text
                addStep("任务结束", detail: finalSummary, isAction: false)
                return
            }

            // 执行工具
            var results: [AnthropicClient.ContentBlock] = []
            for block in toolUses {
                guard case .toolUse(let id, let name, let input) = block else { continue }
                DebugLog.log("[AIAgent] 执行工具: \(name) input=\(input)")
                let result = await executeTool(name: name, input: input)
                addStep(stepSummary(name: name, input: input), detail: result, isAction: true)
                results.append(.toolResult(toolUseID: id, content: result))

                switch name {
                case "finish":
                    finalSummary = result
                    messages.append(AnthropicClient.Message(role: "user", content: results))
                    return
                case "ask_user":
                    pendingQuestion = result
                    messages.append(AnthropicClient.Message(role: "user", content: results))
                    return
                default:
                    break
                }
            }

            // 无变化检测：截图降采样差异（忽略状态栏时钟噪声；元素树对页面内点击不敏感）
            let changed = framesDifferSignificantly(currentScreenshot: current.screenshot)
            if !changed {
                noChangeCount += 1
                DebugLog.log("[AIAgent] 画面无变化 \(noChangeCount)/3")
            } else {
                noChangeCount = 0
            }
            if noChangeCount >= 3 {
                // 卡住：自动收尾（附说明，而不是静默停止）
                finalSummary = "任务卡住（屏幕连续 3 步无变化），已停止"
                addStep("任务卡住（屏幕无变化）", detail: finalSummary, isAction: false)
                return
            }

            messages.append(AnthropicClient.Message(role: "user", content: results))
        }
        addStep("超过最大步数，停止", detail: nil, isAction: false)
    }

    private var lastScreenshotForCompare: String?

    /// 截图降采样差异：缩放后像素差异比例 < 1% 视为无变化
    private func framesDifferSignificantly(currentScreenshot: String) -> Bool {
        guard let prev = lastScreenshotForCompare else {
            lastScreenshotForCompare = currentScreenshot
            return true
        }
        lastScreenshotForCompare = currentScreenshot
        guard let currentData = Data(base64Encoded: currentScreenshot),
              let prevData = Data(base64Encoded: prev),
              let currentImage = CGImageSourceCreateWithData(currentData as CFData, nil),
              let prevImage = CGImageSourceCreateWithData(prevData as CFData, nil),
              let currentCG = CGImageSourceCreateImageAtIndex(currentImage, 0, nil),
              let prevCG = CGImageSourceCreateImageAtIndex(prevImage, 0, nil) else {
            return true
        }
        // 降采样到小尺寸比较
        let w = 32
        let h = 64
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return true
        }
        var prevPixels = [UInt8](repeating: 0, count: w * h * 4)
        ctx.draw(currentCG, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let cur = ctx.data else { return true }
        let curPixels = Array(UnsafeBufferPointer(start: cur.assumingMemoryBound(to: UInt8.self), count: w * h * 4))

        // 第二个 context 绘制上一帧
        guard let ctx2 = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return true
        }
        ctx2.draw(prevCG, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let prevDataPtr = ctx2.data else { return true }
        let prevPixelsArr = Array(UnsafeBufferPointer(start: prevDataPtr.assumingMemoryBound(to: UInt8.self), count: w * h * 4))

        // 差异像素比例（RGB 通道差 > 20）
        var diffCount = 0
        let total = w * h
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let dr = abs(Int(curPixels[i]) - Int(prevPixelsArr[i]))
            let dg = abs(Int(curPixels[i+1]) - Int(prevPixelsArr[i+1]))
            let db = abs(Int(curPixels[i+2]) - Int(prevPixelsArr[i+2]))
            if dr > 20 || dg > 20 || db > 20 { diffCount += 1 }
        }
        return Double(diffCount) / Double(total) > 0.01
    }

    private func stepSummary(name: String, input: [String: AnthropicClient.AnyCodable]) -> String {
        switch name {
        case "tap_element":
            if let i = input["index"]?.value as? Int { return "点击元素 #\(i)" }
        case "tap":
            if let x = input["x"]?.value as? Double, let y = input["y"]?.value as? Double {
                return "点击 (\(Int(x)), \(Int(y)))"
            }
        case "type":
            if let t = input["text"]?.value as? String { return "输入「\(t)」" }
        case "swipe":
            return "滑动"
        case "press_home":
            return "回主屏"
        case "finish":
            return "完成"
        case "ask_user":
            return "询问用户"
        default:
            break
        }
        return name
    }

    // MARK: - 工具执行

    private func executeTool(name: String, input: [String: AnthropicClient.AnyCodable]) async -> String {
        do {
            switch name {
            case "tap_element":
                guard let index = input["index"]?.value as? Int,
                      elements.indices.contains(index),
                      let size = WDAClient.shared.screenSize else {
                    return "错误: 元素编号无效或屏幕尺寸未知"
                }
                let el = elements[index]
                let x = el.relX * size.width
                let y = el.relY * size.height
                try await WDAClient.shared.tap(x: x, y: y)
                return "已点击 #\(index) (\(el.label))"

            case "tap":
                let x = input["x"]?.value as? Double ?? 0
                let y = input["y"]?.value as? Double ?? 0
                try await WDAClient.shared.tap(x: x, y: y)
                return "已点击 (\(Int(x)), \(Int(y)))"

            case "type":
                let text = input["text"]?.value as? String ?? ""
                try await WDAClient.shared.typeText(text)
                return "已输入文本"

            case "swipe":
                let fx = input["from_x"]?.value as? Double ?? 0
                let fy = input["from_y"]?.value as? Double ?? 0
                let tx = input["to_x"]?.value as? Double ?? 0
                let ty = input["to_y"]?.value as? Double ?? 0
                try await WDAClient.shared.drag(fromX: fx, fromY: fy, toX: tx, toY: ty, duration: 0.5)
                return "已滑动"

            case "press_home":
                try await WDAClient.shared.pressHome()
                return "已回主屏"

            case "finish":
                return input["summary"]?.value as? String ?? "完成"

            case "ask_user":
                return input["question"]?.value as? String ?? "需要确认"

            default:
                return "未知工具"
            }
        } catch {
            return "执行失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 观察

    /// 元素（内容区相对坐标 0-1，与设备屏幕坐标解耦）
    private struct Element {
        let relX: Double
        let relY: Double
        let label: String
        let type: String
    }

    private var elements: [Element] = []

    /// 截屏 + 解析元素树（精简可交互元素列表）
    private func observe() async -> (screenshot: String, elements: String)? {
        do {
            let screenshot = try await WDAClient.shared.screenshotBase64()
            lastScreenshot = screenshot

            let xml = try await WDAClient.shared.sourceXML()
            elements = parseElements(from: xml)
            let summary = elements.enumerated().map { index, el in
                "#\(index) [\(el.type)] \(el.label) at (\(Int(el.relX * 100))%, \(Int(el.relY * 100))%)"
            }.joined(separator: "\n")
            return (screenshot, summary.isEmpty ? "(无可交互元素，请用 tap 坐标)" : summary)
        } catch {
            addStep("观察失败: \(error.localizedDescription)", detail: nil, isAction: false)
            return nil
        }
    }

    /// 从 WDA XML 元素树提取可交互元素（有 label 的元素，归一化为相对坐标）
    ///
    /// 兼容两种 XML 格式：
    /// - WDA v16+：x/y/width/height 属性（坐标系可能与 wda/screen 不同）
    /// - 旧版：frame="\{\{x, y\}, \{w, h\}\}"
    /// 统一除以 XML 报告的屏幕尺寸 → 相对坐标，与设备分辨率解耦。
    private func parseElements(from xml: String) -> [Element] {
        // XML 屏幕尺寸（根 Application 元素）
        var screenW: Double = 1
        var screenH: Double = 1
        if let app = try? NSRegularExpression(
            pattern: #"<XCUIElementTypeApplication[^>]*x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)""#
        ) {
            let ns = xml as NSString
            if let m = app.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)) {
                screenW = max(Double(ns.substring(with: m.range(at: 3))) ?? 1, 1)
                screenH = max(Double(ns.substring(with: m.range(at: 4))) ?? 1, 1)
            }
        }

        // 新格式：x/y/width/height 属性
        let newPattern = #"<XCUIElementType(\w+)[^>]*label="([^"]*)"[^>]*x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)""#
        // 旧格式：frame 属性
        let oldPattern = #"<XCUIElementType(\w+)[^>]*label="([^"]*)"[^>]*frame="\{\{([\d.]+), ([\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}""#

        var result: [Element] = []
        let ns = xml as NSString
        let regexes = [(try? NSRegularExpression(pattern: newPattern)), (try? NSRegularExpression(pattern: oldPattern))]

        for regex in regexes.compactMap({ $0 }) {
            for match in regex.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
                let type = ns.substring(with: match.range(at: 1))
                let label = ns.substring(with: match.range(at: 2))
                let x = Double(ns.substring(with: match.range(at: 3))) ?? 0
                let y = Double(ns.substring(with: match.range(at: 4))) ?? 0
                guard !label.isEmpty else { continue }
                result.append(Element(
                    relX: min(x / screenW, 1),
                    relY: min(y / screenH, 1),
                    label: label,
                    type: type
                ))
            }
        }
        return Array(result.prefix(60))
    }
}
