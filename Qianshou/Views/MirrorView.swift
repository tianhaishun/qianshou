import AppKit
import SwiftUI

/// 镜像视图：显示模拟器窗口实时画面 + 连点点位标记 + 点击添加点位
/// 支持缩放（zoom 控件）与拖拽平移
struct MirrorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let frame = appState.mirrorFrame {
                    FrameImageView(frame: frame) { viewPoint in
                        handleTap(at: viewPoint, frame: frame, viewSize: geo.size)
                    } onPan: { delta in
                        offset = CGSize(width: offset.width + delta.width,
                                        height: offset.height + delta.height)
                    } onDoubleClick: {
                        zoom = 1
                        offset = .zero
                    }
                    PointOverlay(frame: frame, viewSize: geo.size, zoom: zoom, offset: offset)
                } else if appState.simulatorWindow != nil {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("正在连接镜像…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    PlaceholderView()
                }
            }
        }
        .overlay(alignment: .bottom) {
            zoomControl
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if let window = appState.simulatorWindow {
                    Text(window.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if appState.clickEngine.isRunning {
                    Text("连点中")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(8)
        }
        .onAppear {
            DebugLog.log("[MirrorView] onAppear")
            Task { await appState.startMirroring() }
        }
        .onDisappear {
            Task { await appState.stopMirroring() }
        }
    }

    // MARK: - 坐标换算

    private var zoomControl: some View {
        HStack(spacing: 6) {
            Button {
                zoom = min(zoom * 1.25, 4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Slider(value: $zoom, in: 1...4, step: 0.1)
                .frame(width: 120)

            Button {
                zoom = max(zoom / 1.25, 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Text(String(format: "%.1fx", zoom))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                zoom = 1
                offset = .zero
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("重置缩放")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 8)
    }

    private func handleTap(at viewPoint: CGPoint, frame: CGImage, viewSize: CGSize) {
        guard !appState.clickEngine.isRunning,
              let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame(),
              let rel = CoordinateMapper.viewToContent(viewPoint,
                                                       frame: CGSize(width: frame.width, height: frame.height),
                                                       viewSize: viewSize,
                                                       contentInFrame: contentInFrame,
                                                       zoom: zoom,
                                                       offset: offset) else { return }
        DebugLog.log("[MirrorView] add point at rel (\(rel.x), \(rel.y))")
        appState.addClickPoint(x: Double(rel.x), y: Double(rel.y))
    }
}

/// 点位标记层：把相对坐标画回视图位置（标记尺寸固定屏幕像素，不随缩放变大）
private struct PointOverlay: View {
    @EnvironmentObject private var appState: AppState
    let frame: CGImage
    let viewSize: CGSize
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame()
        let frameSize = CGSize(width: frame.width, height: frame.height)
        let r = CoordinateMapper.markerRadius(base: 8, zoom: zoom)
        let fontSize = max(10 / max(zoom, 1), 5)

        Canvas { context, _ in
            guard let contentInFrame else { return }
            for (index, point) in appState.clickPoints.enumerated() {
                guard let v = CoordinateMapper.contentToView(
                    CGPoint(x: point.x, y: point.y),
                    frame: frameSize, viewSize: viewSize, contentInFrame: contentInFrame,
                    zoom: zoom, offset: offset
                ) else { continue }
                let vx = v.x
                let vy = v.y

                let circleRect = CGRect(x: vx - r, y: vy - r, width: r * 2, height: r * 2)
                // 描边让深色背景上也清晰
                context.stroke(Ellipse().path(in: circleRect.insetBy(dx: -1.5, dy: -1.5)),
                               with: .color(.black.opacity(0.7)),
                               lineWidth: 1.5)
                context.fill(Ellipse().path(in: circleRect),
                             with: .color(appState.clickEngine.currentPointIndex == index ? .red : .accentColor))
                context.draw(context.resolve(Text("\(index + 1)")
                                .font(.system(size: fontSize, weight: .bold))
                                .foregroundStyle(.white)),
                             at: CGPoint(x: vx, y: vy))
            }
        }
        .allowsHitTesting(false)
    }
}

/// NSView 层渲染 CGImage 帧（比 Image() 逐帧更高效）
private struct FrameImageView: NSViewRepresentable {
    let frame: CGImage
    let onClick: (CGPoint) -> Void
    let onPan: (CGSize) -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> FrameLayerView {
        let view = FrameLayerView()
        view.wantsLayer = true
        view.onClick = { point in
            // NSView 坐标 (y 向上) → SwiftUI 坐标 (y 向下)
            onClick(CGPoint(x: point.x, y: view.bounds.height - point.y))
        }
        view.onPan = onPan
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: FrameLayerView, context: Context) {
        nsView.frameImage = frame
    }
}

final class FrameLayerView: NSView {
    var frameImage: CGImage? {
        didSet {
            layer?.contents = frameImage
        }
    }
    var onClick: ((CGPoint) -> Void)?
    var onPan: ((CGSize) -> Void)?
    var onDoubleClick: (() -> Void)?

    /// 拖拽超过该距离（pt）视为平移而非点击
    private let panThreshold: CGFloat = 5
    private var dragStart: NSPoint?
    private var lastDrag: NSPoint?
    private var isPanning = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        layer?.contentsGravity = .resizeAspect
        layer?.backgroundColor = NSColor.black.cgColor
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        let p = convert(event.locationInWindow, from: nil)
        dragStart = p
        lastDrag = p
        isPanning = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let last = lastDrag else { return }
        let p = convert(event.locationInWindow, from: nil)
        if !isPanning {
            let dx = p.x - start.x
            let dy = p.y - start.y
            if abs(dx) > panThreshold || abs(dy) > panThreshold {
                isPanning = true
            }
        }
        if isPanning {
            // NSView y 向上 → SwiftUI y 向下：平移增量取反 y
            onPan?(CGSize(width: p.x - last.x, height: last.y - p.y))
        }
        lastDrag = p
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            lastDrag = nil
            isPanning = false
        }
        guard !isPanning, let start = dragStart else { return }
        let p = convert(event.locationInWindow, from: nil)
        let dx = p.x - start.x
        let dy = p.y - start.y
        guard abs(dx) <= panThreshold, abs(dy) <= panThreshold else { return }
        onClick?(p)
    }
}

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("没有可显示的模拟器窗口")
                .foregroundStyle(.secondary)
            Text("在左侧选择模拟器并点击「启动」")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
