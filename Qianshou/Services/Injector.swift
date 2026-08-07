import ApplicationServices
import CoreGraphics
import Foundation

/// CGEvent 鼠标点击注入（点击模拟器窗口 = 触摸事件）
///
/// 注入在后台队列执行（事件时序用 sleep 保持，不阻塞主线程）。
enum Injector {

    /// 在屏幕坐标（pt）处注入一次点击
    ///
    /// 不移动真实光标：down/up 事件自带位置参数，事件投递到目标窗口，
    /// 光标保持原位（避免回放时「抢走」用户鼠标）
    static func click(at screenPoint: CGPoint, holdMs: Int = 50) async {
        guard AXIsProcessTrusted() else { return }
        await Task.detached(priority: .userInitiated) {
            let source = CGEventSource(stateID: .hidSystemState)
            CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                    mouseCursorPosition: screenPoint, mouseButton: .left)?.post(tap: .cghidEventTap)
            usleep(useconds_t(holdMs * 1000))
            CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                    mouseCursorPosition: screenPoint, mouseButton: .left)?.post(tap: .cghidEventTap)
        }.value
    }

    /// 注入拖拽（按下→移动→抬起），用于滑动操作
    ///
    /// 同样不移动真实光标：事件自带位置
    static func drag(from start: CGPoint, to end: CGPoint, durationMs: Int = 200, steps: Int = 20) async {
        guard AXIsProcessTrusted(), steps > 0 else { return }
        await Task.detached(priority: .userInitiated) {
            let source = CGEventSource(stateID: .hidSystemState)
            CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                    mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let p = CGPoint(x: start.x + (end.x - start.x) * t,
                                y: start.y + (end.y - start.y) * t)
                CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                        mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
                usleep(useconds_t(durationMs * 1000 / steps))
            }
            CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                    mouseCursorPosition: end, mouseButton: .left)?.post(tap: .cghidEventTap)
        }.value
    }
}
