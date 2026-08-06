import Foundation

/// 回放引擎：按录制序列的时间偏移精确回放点击
@MainActor
final class Player: ObservableObject {

    @Published private(set) var isPlaying = false
    @Published private(set) var progressMs: Int = 0

    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - sequence: 要回放的序列
    ///   - contentRect: 内容区屏幕 rect（回放前取最新）
    ///   - onActivateSimulator: 回放开始前激活模拟器
    func play(sequence: ClickSequence,
              contentRect: @escaping () -> CGRect?,
              onActivateSimulator: () -> Void) {
        guard !isPlaying, !sequence.points.isEmpty else { return }
        isPlaying = true
        progressMs = 0

        onActivateSimulator()
        task = Task { [weak self] in
            let start = ContinuousClock.now
            for point in sequence.points {
                guard !Task.isCancelled else { break }
                // 等待到该点的时间偏移
                let target = start.advanced(by: .milliseconds(point.offsetMs))
                try? await Task.sleep(until: target, clock: .continuous)
                guard !Task.isCancelled,
                      let rect = contentRect() else { break }

                switch point.kind {
                case .click:
                    let screenPoint = CGPoint(
                        x: rect.minX + rect.width * point.x,
                        y: rect.minY + rect.height * point.y
                    )
                    await Injector.click(at: screenPoint)
                case .drag:
                    let startPt = CGPoint(
                        x: rect.minX + rect.width * point.x,
                        y: rect.minY + rect.height * point.y
                    )
                    let endPt = CGPoint(
                        x: rect.minX + rect.width * (point.endX ?? point.x),
                        y: rect.minY + rect.height * (point.endY ?? point.y)
                    )
                    await Injector.drag(from: startPt, to: endPt,
                                        durationMs: point.durationMs ?? 200)
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
