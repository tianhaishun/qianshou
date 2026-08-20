import Foundation

/// 回放引擎：按录制序列的时间偏移精确回放点击
@MainActor
final class Player: ObservableObject {

    @Published private(set) var isPlaying = false
    @Published private(set) var progressMs: Int = 0

    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - sequence: 要回放的序列
    func play(sequence: ClickSequence) {
        guard !isPlaying, !sequence.points.isEmpty else { return }
        isPlaying = true
        progressMs = 0

        task = Task { [weak self] in
            let start = ContinuousClock.now
            for point in sequence.points {
                guard !Task.isCancelled else { break }
                // 等待到该点的时间偏移
                let target = start.advanced(by: .milliseconds(point.offsetMs))
                try? await Task.sleep(until: target, clock: .continuous)
                guard !Task.isCancelled else { break }

                switch point.kind {
                case .click:
                    await Injector.click(relative: CGPoint(x: point.x, y: point.y))
                case .drag:
                    await Injector.drag(
                        fromRel: CGPoint(x: point.x, y: point.y),
                        toRel: CGPoint(x: point.endX ?? point.x, y: point.endY ?? point.y),
                        durationMs: point.durationMs ?? 200
                    )
                case .waitElement:
                    // 条件等待：元素出现或超时（超时继续，不中断序列）
                    if let label = point.elementLabel, !label.isEmpty {
                        let appeared = await Injector.waitForElement(
                            label: label,
                            timeoutMs: point.durationMs ?? 5000
                        )
                        DebugLog.log("[Player] waitElement \"\(label)\" \(appeared ? "✓ 出现" : "✗ 超时")")
                    }
                }
                self?.progressMs = point.offsetMs
                DebugLog.log("[Player] replayed @\(point.offsetMs)ms kind=\(point.kind.rawValue)")
            }
            self?.isPlaying = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isPlaying = false
    }
}
