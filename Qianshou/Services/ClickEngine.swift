import Foundation

/// 连点引擎：按点位列表循环点击，可随时取消
///
/// 流程：激活模拟器窗口 → 每轮依次点击每个点 → 点间隔 intervalMs → 共 loops 轮
@MainActor
final class ClickEngine: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var currentPointIndex: Int?
    @Published private(set) var currentLoop: Int = 0

    /// 执行中的总轮数（用于进度显示）
    private(set) var totalLoops = 1

    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - points: 内容区相对坐标点位
    ///   - intervalMs: 同一轮内点与点之间的间隔
    ///   - loopIntervalMs: 轮与轮之间的间隔
    ///   - loops: 总轮数（<=0 表示无限循环直到手动停止）
    ///   - contentRect: 内容区屏幕 rect（注入前取最新）
    ///   - onActivateSimulator: 开始前激活模拟器窗口（保证不被遮挡）
    func start(points: [ClickPoint],
               intervalMs: Int,
               loopIntervalMs: Int,
               loops: Int,
               contentRect: @escaping () -> CGRect?,
               onActivateSimulator: () -> Void) {
        guard !isRunning, !points.isEmpty else { return }
        isRunning = true
        currentLoop = 0
        currentPointIndex = nil
        totalLoops = loops

        onActivateSimulator()
        // 等待窗口激活完成
        let activationDelay: UInt64 = 300_000_000

        task = Task { [weak self] in
            var loop = 0
            while !Task.isCancelled {
                loop += 1
                self?.currentLoop = loop
                for (i, point) in points.enumerated() {
                    guard !Task.isCancelled else { break }
                    self?.currentPointIndex = i
                    try? await Task.sleep(nanoseconds: activationDelay)
                    guard let rect = contentRect() else {
                        self?.stop()
                        return
                    }
                    let screenPoint = CGPoint(
                        x: rect.minX + rect.width * point.x,
                        y: rect.minY + rect.height * point.y
                    )
                    Injector.click(at: screenPoint)
                    if i < points.count - 1 {
                        try? await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
                    }
                }
                self?.currentPointIndex = nil
                if loops > 0 && loop >= loops { break }
                if loopIntervalMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(loopIntervalMs) * 1_000_000)
                }
            }
            self?.isRunning = false
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        currentPointIndex = nil
    }
}
