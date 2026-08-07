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
    ///   - points: 内容区相对坐标点位（0-1，XCTest 注入与窗口位置无关）
    ///   - intervalMs: 同一轮内点与点之间的间隔
    ///   - loopIntervalMs: 轮与轮之间的间隔
    ///   - loops: 总轮数（<=0 表示无限循环直到手动停止）
    func start(points: [ClickPoint],
               intervalMs: Int,
               loopIntervalMs: Int,
               loops: Int) {
        guard !isRunning, !points.isEmpty else { return }
        isRunning = true
        currentLoop = 0
        currentPointIndex = nil
        totalLoops = loops

        task = Task { [weak self] in
            var loop = 0
            while !Task.isCancelled {
                loop += 1
                self?.currentLoop = loop
                for (i, point) in points.enumerated() {
                    guard !Task.isCancelled else { break }
                    self?.currentPointIndex = i
                    await Injector.click(relative: CGPoint(x: point.x, y: point.y))
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
