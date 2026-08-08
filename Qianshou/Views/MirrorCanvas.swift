import AppKit
import SwiftUI

/// 镜像画布 v2 —— 驾驶舱主屏
///
/// 交互逻辑重构:
/// - 悬停显示十字准星 + 实时相对坐标读数(mono)
/// - 点位可直接拖拽微调(旧版只能删了重加)
/// - 点/拖/双击手势语义不变,运行中全部锁定
/// - 缩放控制去渐变,改为细线 + mono 读数
struct MirrorCanvas: View {
    @EnvironmentObject private var appState: AppState
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var hoverLocation: CGPoint?

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
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p): hoverLocation = p
                        case .ended: hoverLocation = nil
                        }
                    }
                    PointOverlay(frame: frame, viewSize: geo.size, zoom: zoom, offset: offset)
                    crosshairOverlay(geo: geo, frame: frame)
                } else if appState.simulatorWindow != nil {
                    connectingState
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hoverLocation != nil ? DesignTokens.borderStrong : DesignTokens.border, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                deviceCapsule.padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if appState.clickEngine.isRunning {
                    runningChip.padding(12)
                }
            }
            .overlay(alignment: .bottom) {
                zoomControl.padding(.bottom, 10)
            }
        }
        .onAppear {
            DebugLog.log("[MirrorCanvas] onAppear")
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
                Controls.StatusDot(color: DesignTokens.ok, pulsing: true)
                Text(window.title)
                    .font(DesignTokens.ui(11, weight: .semibold))
                    .foregroundStyle(DesignTokens.accent)
                Text("已启动")
                    .font(DesignTokens.ui(10))
                    .foregroundStyle(DesignTokens.ok)
            } else {
                Controls.StatusDot(color: DesignTokens.off)
                Text("未连接")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.bgCard.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    private var runningChip: some View {
        HStack(spacing: 6) {
            Controls.StatusDot(color: DesignTokens.record, pulsing: true)
            Text("第 \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮")
                .font(DesignTokens.mono(11, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.bgCard.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    private var connectingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在连接镜像…")
                .font(DesignTokens.ui(12))
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 34))
                .foregroundStyle(DesignTokens.textTertiary)
            VStack(spacing: 4) {
                Text("未选择设备")
                    .font(DesignTokens.ui(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("从左上角选择或启动一台模拟器,镜像将出现在这里")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Button {
                Task { await appState.startMirroring() }
            } label: {
                Label("连接镜像", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(Controls.SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .padding(1)
        )
    }

    // MARK: - 缩放控制(细线,去渐变)

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Button {
                zoom = min(zoom * 1.25, 4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)

            Slider(value: $zoom, in: 1...4, step: 0.25)
                .tint(DesignTokens.accent)
                .frame(width: 110)

            Button {
                zoom = max(zoom / 1.25, 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)

            Text(String(format: "%.2g×", zoom))
                .font(DesignTokens.mono(11, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
                .contentTransition(.numericText())
                .animation(DesignTokens.quick, value: zoom)
                .frame(width: 38, alignment: .center)

            Rectangle()
                .fill(DesignTokens.border)
                .frame(width: 1, height: 16)

            ForEach([1.0, 2.0, 4.0], id: \.self) { level in
                Button {
                    withAnimation(DesignTokens.quick) {
                        zoom = level
                        offset = .zero
                    }
                } label: {
                    Text("\(Int(level))×")
                        .font(DesignTokens.mono(10, weight: .semibold))
                        .foregroundStyle(abs(zoom - level) < 0.01 ? DesignTokens.accent : DesignTokens.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            if abs(zoom - level) < 0.01 {
                                RoundedRectangle(cornerRadius: 4).fill(DesignTokens.accentDim)
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
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("适应窗口")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.bgCard.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    // MARK: - 十字准星

    private func crosshairOverlay(geo: GeometryProxy, frame: CGImage) -> some View {
        ZStack {
            if let h = hoverLocation, !appState.clickEngine.isRunning {
                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 1)
                    .frame(height: geo.size.height)
                    .position(x: h.x, y: geo.size.height / 2)
                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(height: 1)
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width / 2, y: h.y)
                if let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame(),
                   let rel = CoordinateMapper.viewToContent(
                       h,
                       frame: CGSize(width: frame.width, height: frame.height),
                       viewSize: geo.size,
                       contentInFrame: contentInFrame,
                       zoom: zoom, offset: offset
                   ) {
                    Text(String(format: "x %.2f · y %.2f", rel.x, rel.y))
                        .font(DesignTokens.mono(10, weight: .medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.bgCardRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DesignTokens.border, lineWidth: 1)
                        )
                        .position(
                            x: min(max(h.x + 14, 56), max(geo.size.width - 56, 56)),
                            y: max(h.y - 16, 20)
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 坐标换算

    private func handleTap(at viewPoint: CGPoint, frame: CGImage, viewSize: CGSize) {
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
        DebugLog.log("[MirrorCanvas] add point at rel (\(rel.x), \(rel.y))")
        appState.addClickPoint(x: Double(rel.x), y: Double(rel.y))
    }
}

// MARK: - 点位层(可拖拽)

/// 点位标记层 v2:ZStack + 独立手势,支持直接拖拽微调
private struct PointOverlay: View {
    @EnvironmentObject private var appState: AppState
    let frame: CGImage
    let viewSize: CGSize
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame()
        let frameSize = CGSize(width: frame.width, height: frame.height)

        ZStack {
            if let contentInFrame {
                ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                    if let v = CoordinateMapper.contentToView(
                        CGPoint(x: point.x, y: point.y),
                        frame: frameSize, viewSize: viewSize,
                        contentInFrame: contentInFrame,
                        zoom: zoom, offset: offset
                    ) {
                        marker(for: index, point: point)
                            .position(x: v.x, y: v.y)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        guard !appState.clickEngine.isRunning,
                                              !appState.player.isPlaying,
                                              !appState.recorder.isRecording else { return }
                                        movePoint(index: index, to: value.location,
                                                  frameSize: frameSize, contentInFrame: contentInFrame)
                                    }
                            )
                    }
                }
            }
        }
        .allowsHitTesting(!appState.clickPoints.isEmpty)
        .animation(DesignTokens.quick, value: appState.clickPoints)
    }

    private func isHit(_ index: Int) -> Bool {
        appState.clickEngine.currentPointIndex == index
    }

    private func isDone(_ index: Int) -> Bool {
        guard let current = appState.clickEngine.currentPointIndex,
              appState.clickEngine.isRunning else { return false }
        return index < current
    }

    private func marker(for index: Int, point: ClickPoint) -> some View {
        let hit = isHit(index)
        let done = isDone(index)
        let fill: Color = hit ? DesignTokens.err : (done ? DesignTokens.ok.opacity(0.5) : DesignTokens.accent)
        return ZStack {
            Circle()
                .fill(fill)
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            Text("\(index + 1)")
                .font(DesignTokens.mono(9, weight: .bold))
                .foregroundStyle(Color(hex: 0x06121C))
            if done {
                Text("✓")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignTokens.ok)
                    .position(x: 11, y: 11)
            }
        }
        .frame(width: DesignTokens.markerDiameter, height: DesignTokens.markerDiameter)
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        .help("\(point.label) · 拖拽微调")
        .accessibilityLabel("\(point.label) \(index + 1)")
    }

    /// 视图坐标 → 相对坐标,原位更新点位
    private func movePoint(index: Int, to viewPoint: CGPoint, frameSize: CGSize, contentInFrame: CGRect) {
        guard let rel = CoordinateMapper.viewToContent(viewPoint,
                                                       frame: frameSize, viewSize: viewSize,
                                                       contentInFrame: contentInFrame,
                                                       zoom: zoom, offset: offset) else { return }
        var pts = appState.clickPoints
        guard pts.indices.contains(index) else { return }
        pts[index].x = Double(rel.x)
        pts[index].y = Double(rel.y)
        appState.clickPoints = pts
    }
}

// MARK: - 帧渲染层(保留 NSView 方案:逐帧比 Image() 高效)

/// NSView 层渲染 CGImage 帧
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

    /// 拖拽超过该距离(pt)视为平移而非点击
    private let panThreshold: CGFloat = 5
    private var dragStart: NSPoint?
    private var lastDrag: NSPoint?
    private var isPanning = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = CALayer()
        layer?.contentsGravity = .resizeAspect
        layer?.backgroundColor = NSColor(hex: 0x090F1B).cgColor
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
            // NSView y 向上 → SwiftUI y 向下:平移增量取反 y
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
