import Foundation

/// 序列回放核心（App 与 CLI 共用）
///
/// 按录制时间偏移精确回放点击/拖拽，支持循环轮数。
/// 坐标：内容区相对 (0-1) → 设备逻辑 pt（WDA screenSize）
@MainActor
enum SequenceRunner {

    enum RunnerError: LocalizedError {
        case wdaNotRunning
        case noScreenSize

        var errorDescription: String? {
            switch self {
            case .wdaNotRunning: return "WDA 未运行（scripts/start_wda.sh）"
            case .noScreenSize: return "无法获取设备屏幕尺寸"
            }
        }
    }

    /// 元素树中按 label 查找元素（失败返回 nil → 回退坐标）
    private static func findElementByLabel(_ label: String) async -> UIElement? {
        guard let xml = try? await WDAClient.shared.sourceXML() else { return nil }
        return ElementTree.match(FlowSelector(text: label), in: ElementTree.parse(xml))
    }

    /// 回放序列
    /// - Parameters:
    ///   - sequence: 序列（loops 字段控制轮数）
    ///   - onAction: 每个动作执行后回调（动作索引，用于进度显示）
    static func run(sequence: ClickSequence,
                    onAction: @escaping (Int, Int) -> Void = { _, _ in }) async throws {
        try await WDAClient.shared.checkAlive()
        guard WDAClient.shared.isAlive else { throw RunnerError.wdaNotRunning }
        try await WDAClient.shared.ensureSession()
        guard let size = WDAClient.shared.screenSize else { throw RunnerError.noScreenSize }

        let total = sequence.points.count
        let loops = max(sequence.loops, 1)

        for loop in 0..<loops {
            let start = ContinuousClock.now
            for (index, point) in sequence.points.enumerated() {
                // 等待到该动作的时间偏移
                let target = start.advanced(by: .milliseconds(point.offsetMs))
                try? await Task.sleep(until: target, clock: .continuous)

                switch point.kind {
                case .waitElement:
                    // 条件等待：轮询元素树直到 elementLabel 出现或超时（超时继续，不中断序列）
                    if let label = point.elementLabel, !label.isEmpty {
                        let timeout = TimeInterval(max(point.durationMs ?? 5000, 0)) / 1000
                        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
                        var appeared = false
                        while ContinuousClock.now < deadline {
                            if let _ = await findElementByLabel(label) {
                                appeared = true
                                break
                            }
                            try? await Task.sleep(nanoseconds: 300_000_000)
                        }
                        DebugLog.log("[SequenceRunner] waitElement \"\(label)\" \(appeared ? "✓ 出现" : "✗ 超时(\(String(format: "%.1f", timeout))s)")")
                    }
                case .click:
                    // 元素定位优先：录到了元素标签就按元素点（换机型不失效），
                    // 元素未找到或未捕获标签时回退坐标
                    if let label = point.elementLabel, !label.isEmpty,
                       let el = await findElementByLabel(label) {
                        let tx = el.centerX * size.width
                        let ty = el.centerY * size.height
                        DebugLog.log("[SequenceRunner] tap element \"\(label)\" @(\(tx), \(ty))")
                        do {
                            try await WDAClient.shared.tap(x: tx, y: ty)
                        } catch {
                            DebugLog.log("[SequenceRunner] tap FAILED: \(error)")
                        }
                    } else {
                        let tx = point.x * size.width
                        let ty = point.y * size.height
                        DebugLog.log("[SequenceRunner] tap (\(tx), \(ty)) size=\(size)")
                        do {
                            try await WDAClient.shared.tap(x: tx, y: ty)
                        } catch {
                            DebugLog.log("[SequenceRunner] tap FAILED: \(error)")
                        }
                    }
                case .drag:
                    try await WDAClient.shared.drag(
                        fromX: point.x * size.width,
                        fromY: point.y * size.height,
                        toX: (point.endX ?? point.x) * size.width,
                        toY: (point.endY ?? point.y) * size.height,
                        duration: max(Double(point.durationMs ?? 200) / 1000, 0.5)
                    )
                }
                onAction(index, total)
            }
        }
    }
}
