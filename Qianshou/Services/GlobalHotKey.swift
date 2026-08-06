import AppKit
import Foundation

/// 全局热键：F8 开始/停止连点（任意前台应用下生效）
///
/// 用全局事件监听实现（无需 Carbon API），需要辅助功能权限（与点击注入共用）。
final class GlobalHotKey {

    /// F8 的 keyCode（kVK_F8）
    private let f8KeyCode: UInt16 = 100

    private var monitor: Any?

    /// - Parameter onToggle: 主线程回调，F8 按下时触发
    func install(onToggle: @escaping () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == self.f8KeyCode else { return }
            DispatchQueue.main.async {
                onToggle()
            }
        }
    }

    func uninstall() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        uninstall()
    }
}
