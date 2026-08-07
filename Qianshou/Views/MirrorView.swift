import AppKit
import SwiftUI

/// 镜像视图：模拟器实时画面卡片 + 点位标记（渐变徽标/命中脉冲/完成对勾）+ 缩放控制
struct MirrorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var isHovering = false

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
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                } else {
                    mirrorEmptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHovering ? DesignTokens.borderHover : DesignTokens.borderCard, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 28, y: 10)
            .overlay(alignment: .topLeading) {
                deviceCapsule
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if appState.clickEngine.isRunning {
                    runningChip
                        .padding(12)
                }
            }
            .overlay(alignment: .bottom) {
                zoomControl
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            DebugLog.log("[MirrorView] onAppear")
            Task { await appState.startMirroring() }
        }
        .onDisappear {
            Task { await appState.stopMirroring() }
        }
    }

    // MARK: - 悬浮元素

    private var deviceCapsule: some View {
        HStack(spacing: 6) {
            if let window = appState.simulatorWindow {
                StatusDot(isBooted: true)
                Text(window.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.brandBright)
                Text("已启动")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.ok)
            } else {
                Text("未连接")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(DesignTokens.borderCard, lineWidth: 1))
        )
    }

    private var runningChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(DesignTokens.err)
                .frame(width: 6, height: 6)
            Text("第 \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.ultraThinMaterial))
    }

    private var mirrorEmptyState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                .stroke(DesignTokens.borderCard, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .frame(width: 280, height: 180)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 36))
                            .foregroundStyle(DesignTokens.textTertiary)
                        Text("未选择设备")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.textSecondary)
                        Text("从左侧选择或启动一台模拟器")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.textTertiary)
                        Button {
                            Task { await appState.startMirroring() }
                        } label: {
                            Label("连接镜像", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                    }
                }
        }
    }

    // MARK: - 缩放控制

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Button {
                zoom = min(zoom * 1.25, 4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Slider(value: $zoom, in: 1...4, step: 0.25)
                .tint(DesignTokens.brandBright)
                .frame(width: 120)

            Button {
                zoom = max(zoom / 1.25, 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Text(String(format: "%.2g×", zoom))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignTokens.textSecondary)
                .contentTransition(.numericText())
                .animation(DesignTokens.quick, value: zoom)
                .frame(width: 40, alignment: .center)

            ForEach([1.0, 2.0, 4.0], id: \.self) { level in
                Button {
                    withAnimation(DesignTokens.quick) {
                        zoom = level
                        offset = .zero
                    }
                } label: {
                    Text("\(Int(level))×")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(abs(zoom - level) < 0.01 ? .white : DesignTokens.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            if abs(zoom - level) < 0.01 {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(DesignTokens.brandGradient)
                            } else {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.clear)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(DesignTokens.quick) {
                    zoom = 1
                    offset = .zero
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("适应窗口")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(DesignTokens.borderCard, lineWidth: 1))
        .padding(.bottom, 10)
    }

    // MARK: - 坐标换算

    private func handleTap(at viewPoint: CGPoint, frame: CGImage, viewSize: CGSize) {
        // 连点运行中、录制进行中、回放进行中都不可添加点位
        guard !appState.clickEngine.isRunning,
              !appState.recorder.isRecording,
              !appState.player.isPlaying,
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

/// 点位标记层：渐变徽标 + 命中脉冲 + 完成对勾
private struct PointOverlay: View {
    @EnvironmentObject private var appState: AppState
    let frame: CGImage
    let viewSize: CGSize
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame()
        let frameSize = CGSize(width: frame.width, height: frame.height)
        let markerR = DesignTokens.markerDiameter / 2

        Canvas { context, _ in
            guard let contentInFrame else { return }
            for (index, point) in appState.clickPoints.enumerated() {
                guard let v = CoordinateMapper.contentToView(
                    CGPoint(x: point.x, y: point.y),
                    frame: frameSize, viewSize: viewSize, contentInFrame: contentInFrame,
                    zoom: zoom, offset: offset
                ) else { continue }
                let isHit = appState.clickEngine.currentPointIndex == index
                let isDone = appState.clickEngine.isRunning && appState.clickEngine.currentPointIndex != nil
                    && index < (appState.clickEngine.currentPointIndex ?? 0)

                let rect = CGRect(x: v.x - markerR, y: v.y - markerR,
                                  width: DesignTokens.markerDiameter, height: DesignTokens.markerDiameter)

                // 描边（浅色画面上可见）
                context.stroke(Circle().path(in: rect.insetBy(dx: -2, dy: -2)),
                               with: .color(Color(hex: 0x0A111F).opacity(0.8)),
                               lineWidth: 3)
                // 填充：命中红 / 完成半透明 / 常态渐变
                if isHit {
                    context.fill(Circle().path(in: rect), with: .color(DesignTokens.err))
                } else if isDone {
                    context.fill(Circle().path(in: rect), with: .color(DesignTokens.ok.opacity(0.45)))
                } else {
                    let gradient = Gradient(colors: [DesignTokens.brandDeep, DesignTokens.brandBright])
                    let g = GraphicsContext.Shading.linearGradient(gradient, startPoint: rect.origin,
                                                                   endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
                    context.fill(Circle().path(in: rect), with: g)
                }
                // 序号
                context.draw(context.resolve(Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)),
                             at: v)
                // 完成对勾
                if isDone {
                    context.draw(context.resolve(Text("✓")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)),
                                 at: CGPoint(x: v.x + markerR * 0.8, y: v.y + markerR * 0.8))
                }
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
        layer?.backgroundColor = NSColor(hex: 0x0A111F).cgColor
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

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 状态点：booted 呼吸动画（镜像卡片 header 复用）
struct StatusDot: View {
    let isBooted: Bool

    var body: some View {
        Circle()
            .fill(isBooted ? DesignTokens.ok : DesignTokens.off)
            .frame(width: 7, height: 7)
            .shadow(color: isBooted ? DesignTokens.ok.opacity(0.6) : .clear, radius: 3)
            .animation(
                isBooted
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: isBooted
            )
    }
}
