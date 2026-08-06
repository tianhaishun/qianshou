import ApplicationServices
import CoreGraphics
import Foundation

/// CGEvent 鼠标点击注入（点击模拟器窗口 = 触摸事件）
enum Injector {

    /// 在屏幕坐标（pt）处注入一次点击
    static func click(at screenPoint: CGPoint, holdMs: Int = 50) {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: screenPoint, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(useconds_t(20_000))
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                mouseCursorPosition: screenPoint, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(useconds_t(holdMs * 1000))
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                mouseCursorPosition: screenPoint, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    /// 注入拖拽（按下→移动→抬起），用于滑动操作
    static func drag(from start: CGPoint, to end: CGPoint, durationMs: Int = 200, steps: Int = 20) {
        guard AXIsProcessTrusted(), steps > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(useconds_t(20_000))
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
    }
}
