import CoreGraphics
import Foundation

/// 触摸注入（XCTest 路径，通过模拟器内 WDA）—— 不涉及 macOS 鼠标事件
///
/// 输入为内容区相对坐标（0-1），内部换算为设备逻辑 pt 后调用 WDA。
/// 模拟器窗口移动/缩放不影响注入准确性（与窗口位置无关）。
@MainActor
enum Injector {

    /// 注入一次点击（内容区相对坐标）
    static func click(relative: CGPoint) async {
        guard let size = WDAClient.shared.screenSize else { return }
        let x = relative.x * size.width
        let y = relative.y * size.height
        try? await WDAClient.shared.tap(x: x, y: y)
    }

    /// 等待元素出现（轮询元素树；超时返回 false，不抛错）
    static func waitForElement(label: String, timeoutMs: Int) async -> Bool {
        let timeout = TimeInterval(max(timeoutMs, 0)) / 1000
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while ContinuousClock.now < deadline {
            if let xml = try? await WDAClient.shared.sourceXML(),
               ElementTree.match(FlowSelector(text: label), in: ElementTree.parse(xml)) != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    /// 注入拖拽（起点/终点均为内容区相对坐标）
    static func drag(fromRel: CGPoint, toRel: CGPoint, durationMs: Int = 200) async {
        guard let size = WDAClient.shared.screenSize else { return }
        let fx = fromRel.x * size.width
        let fy = fromRel.y * size.height
        let tx = toRel.x * size.width
        let ty = toRel.y * size.height
        // WDA 要求 duration 0.5-60s；短拖拽按 0.5s 下限
        let duration = max(Double(durationMs) / 1000, 0.5)
        try? await WDAClient.shared.drag(fromX: fx, fromY: fy, toX: tx, toY: ty, duration: duration)
    }
}
