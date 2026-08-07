import CoreGraphics
import Foundation

/// 定位 Simulator 窗口并计算「内容区」rect（屏幕坐标 pt）
///
/// 注入点击与镜像捕获都基于同一个内容区 rect，保证两边坐标一一对应。
/// 内容区高度通过「窗口高 - 标题栏高」自校准：首次捕获拿到画面像素尺寸后，
/// 调用 `calibrate(contentPixelSize:)` 修正标题栏高度估算误差。
///
/// 多设备支持：`refresh(preferredTitle:)` 优先匹配指定设备名（窗口 title = 设备名）。
final class WindowLocator {

    struct SimulatorWindow: Equatable {
        let windowID: CGWindowID
        /// 整个窗口 frame（含标题栏），屏幕坐标 pt
        var frame: CGRect
        let title: String
        /// 内容区 rect（去掉标题栏/边框），屏幕坐标 pt
        var contentRect: CGRect
        /// 标题栏+边框高度（pt）
        var topInset: CGFloat
    }

    private(set) var window: SimulatorWindow?

    /// 标题栏高度估算值（pt），首次捕获后用 calibrate 修正
    private var estimatedTopInset: CGFloat = 28

    /// 在屏幕可见窗口里找 Simulator 主窗口
    /// - Parameter preferredTitle: 优先匹配的窗口标题（设备名），如 "iPhone 17 Pro"
    func refresh(preferredTitle: String? = nil) {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            window = nil
            return
        }
        var fallback: SimulatorWindow?
        for w in info {
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            guard owner == "Simulator", layer == 0 else { continue }
            let id = w[kCGWindowNumber as String] as? UInt32 ?? 0
            let title = w[kCGWindowName as String] as? String ?? ""
            guard let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict) else { continue }
            // 跳过名字为空的辅助面板；主窗口名形如 "iPhone 17 Pro"
            guard !title.isEmpty else { continue }

            let candidate = SimulatorWindow(
                windowID: CGWindowID(id),
                frame: rect,
                title: title,
                contentRect: rect.insetBy(dx: 0, dy: 0).withTopInset(estimatedTopInset),
                topInset: estimatedTopInset
            )
            // 精确匹配设备名（Simulator 窗口标题 = 设备名），
            // 避免 "iPhone 17 Pro" 误匹配 "iPhone 17 Pro Max"
            if let preferredTitle, title == preferredTitle {
                window = candidate
                return
            }
            fallback = fallback ?? candidate
        }
        window = fallback
        if let preferredTitle, let window, window.title != preferredTitle {
            // 首选设备窗口不可见时回退到别的模拟器窗口（用户可能混淆注入目标）
            DebugLog.log("[WindowLocator] 首选窗口「\(preferredTitle)」不可见，回退到「\(window.title)」")
        }
    }

    /// 内容区在捕获帧（窗口全图）内的 rect，归一化 0...1
    /// 帧像素坐标 → 内容区相对坐标的换算基础
    func contentRectNormalizedInFrame() -> CGRect? {
        guard let window else { return nil }
        let frameW = window.frame.width
        let frameH = window.frame.height
        guard frameW > 0, frameH > 0 else { return nil }
        // 内容区顶部 = frame.minY + topInset，水平居中
        let x = (frameW - window.contentRect.width) / 2 / frameW
        let y = window.topInset / frameH
        let w = window.contentRect.width / frameW
        let h = window.contentRect.height / frameH
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 用实际捕获帧尺寸校准内容区
    /// - Parameters:
    ///   - contentPixelSize: 捕获帧的像素尺寸
    ///   - frameSize: 窗口 frame 的 pt 尺寸（自动推导 scale = 像素 / pt，兼容 Retina）
    func calibrate(contentPixelSize: CGSize, frameSize: CGSize) {
        guard let window, frameSize.width > 0 else { return }
        let scale = contentPixelSize.width / frameSize.width
        guard scale > 0 else { return }
        let contentW = contentPixelSize.width / scale
        let contentH = contentPixelSize.height / scale
        // 内容区左右居中于窗口、顶部紧贴标题栏下沿
        let x = window.frame.minX + (window.frame.width - contentW) / 2
        let topInset = window.frame.height - contentH
        self.window = SimulatorWindow(
            windowID: window.windowID,
            frame: window.frame,
            title: window.title,
            contentRect: CGRect(x: x, y: window.frame.minY + topInset, width: contentW, height: contentH),
            topInset: topInset
        )
    }
}

private extension CGRect {
    func withTopInset(_ inset: CGFloat) -> CGRect {
        CGRect(x: minX, y: minY + inset, width: width, height: height - inset)
    }
}
