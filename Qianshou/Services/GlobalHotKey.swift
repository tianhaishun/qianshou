import AppKit
import ApplicationServices
import Foundation

/// 全局热键：F8 开始/停止连点（任意前台应用下生效）
///
/// - 全局监听（其他 App 前台时）：`addGlobalMonitorForEvents`，需要辅助功能权限
/// - 本地监听（本 App 前台时）：`addLocalMonitorForEvents`，无需额外权限
/// - 两路都过滤 `isARepeat`，长按 F8 不会重复触发
final class GlobalHotKey {

    /// F8 的 keyCode（kVK_F8）
    private let f8KeyCode: UInt16 = 100

    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// - Parameter onToggle: 主线程回调，F8 按下时触发
    /// - Returns: 是否安装成功（无辅助功能权限时全局监听不生效）
    @discardableResult
    func install(onToggle: @escaping () -> Void) -> Bool {
        guard globalMonitor == nil else { return true }
        let hasAccessibility = AXIsProcessTrusted()

        // 本 App 前台时的热键（本地监听，无需辅助功能权限）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !event.isARepeat, event.keyCode == self.f8KeyCode else { return event }
            DispatchQueue.main.async { onToggle() }
            return event
        }

        guard hasAccessibility else { return false }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !event.isARepeat, event.keyCode == self.f8KeyCode else { return }
            DispatchQueue.main.async { onToggle() }
        }
        return true
    }

    func uninstall() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    deinit {
        uninstall()
    }
}
