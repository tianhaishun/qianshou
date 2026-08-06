import CoreGraphics
import Foundation

/// 纯函数坐标换算：视图 ↔ 帧 ↔ 内容区相对 ↔ 屏幕
///
/// 所有换算基于同一约定：
/// - 帧 = 捕获的窗口全图（含标题栏）
/// - 内容区相对坐标 = 0...1，相对内容区左上角（连点/录制的点位都存这个）
/// - 内容区在帧内的位置用 `contentInFrame`（归一化 0...1）描述
enum CoordinateMapper {

    /// aspectFit 后画面在视图中的绘制 rect
    /// - Parameters:
    ///   - zoom: 放大倍数（1 = 适配窗口），放大以视图中心为基准
    ///   - offset: 放大后平移偏移（pt）
    static func drawRect(frame: CGSize, viewSize: CGSize, zoom: CGFloat = 1, offset: CGSize = .zero) -> CGRect? {
        guard frame.width > 0, frame.height > 0, viewSize.width > 0, viewSize.height > 0, zoom > 0 else { return nil }
        let scale = min(viewSize.width / frame.width, viewSize.height / frame.height) * zoom
        let w = frame.width * scale
        let h = frame.height * scale
        let x = (viewSize.width - w) / 2 + offset.width
        let y = (viewSize.height - h) / 2 + offset.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 视图坐标 → 帧归一化坐标（0...1，含边界判定）
    static func viewToFrame(_ p: CGPoint, frame: CGSize, viewSize: CGSize, zoom: CGFloat = 1, offset: CGSize = .zero) -> CGPoint? {
        guard let draw = drawRect(frame: frame, viewSize: viewSize, zoom: zoom, offset: offset), draw.contains(p) else { return nil }
        return CGPoint(x: (p.x - draw.minX) / draw.width, y: (p.y - draw.minY) / draw.height)
    }

    /// 帧归一化坐标 → 内容区相对坐标（0...1）；落在内容区外返回 nil
    static func frameToContent(_ p: CGPoint, contentInFrame: CGRect) -> CGPoint? {
        guard contentInFrame.width > 0, contentInFrame.height > 0 else { return nil }
        let rx = (p.x - contentInFrame.minX) / contentInFrame.width
        let ry = (p.y - contentInFrame.minY) / contentInFrame.height
        guard rx >= 0, rx <= 1, ry >= 0, ry <= 1 else { return nil }
        return CGPoint(x: rx, y: ry)
    }

    /// 内容区相对坐标 → 屏幕坐标（pt）
    static func contentToScreen(_ rel: CGPoint, contentRect: CGRect) -> CGPoint {
        CGPoint(x: contentRect.minX + contentRect.width * rel.x,
                y: contentRect.minY + contentRect.height * rel.y)
    }

    /// 视图坐标 → 内容区相对坐标（一键换算，支持缩放/平移）
    static func viewToContent(_ p: CGPoint, frame: CGSize, viewSize: CGSize, contentInFrame: CGRect,
                              zoom: CGFloat = 1, offset: CGSize = .zero) -> CGPoint? {
        guard let inFrame = viewToFrame(p, frame: frame, viewSize: viewSize, zoom: zoom, offset: offset) else { return nil }
        return frameToContent(inFrame, contentInFrame: contentInFrame)
    }

    /// 内容区相对坐标 → 视图坐标（用于点位标记渲染，支持缩放/平移）
    static func contentToView(_ rel: CGPoint, frame: CGSize, viewSize: CGSize, contentInFrame: CGRect,
                              zoom: CGFloat = 1, offset: CGSize = .zero) -> CGPoint? {
        guard let draw = drawRect(frame: frame, viewSize: viewSize, zoom: zoom, offset: offset) else { return nil }
        let fx = contentInFrame.minX + rel.x * contentInFrame.width
        let fy = contentInFrame.minY + rel.y * contentInFrame.height
        guard fx >= 0, fx <= 1, fy >= 0, fy <= 1 else { return nil }
        return CGPoint(x: draw.minX + fx * draw.width, y: draw.minY + fy * draw.height)
    }

    /// 点位标记的屏幕固定半径（放大时保持视觉尺寸不变）
    static func markerRadius(base: CGFloat, zoom: CGFloat) -> CGFloat {
        base / max(zoom, 1)
    }
}
