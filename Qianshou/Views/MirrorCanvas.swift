import AppKit
import SwiftUI

/// 镜像画布 v4 —— 印版(plate):一块被认真装帧过的画面
///
/// 排版改动(v3 的三个浮动 chip → 底部一条 mono 图注条):
/// - 设备名 / 状态 / 运行轮次 与 缩放控制 合入图注条(32pt,印刷线分隔)
/// - 悬停坐标读数改为墨底纸字小片(像胶片时间码),不再套白框
/// - 圆角 12 → 8,胶囊退役
///
/// 交互逻辑(v2 已定,零改动):
/// - 悬停显示十字准星 + 实时相对坐标读数(mono)
/// - 点位可直接拖拽微调(旧版只能删了重加)
/// - 点/拖/双击手势语义不变,运行中全部锁定
struct MirrorCanvas: View {
    @EnvironmentObject private var appState: AppState
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var hoverLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let frame = appState.mirrorFrame {
                    FrameImageView(frame: frame, zoom: zoom, offset: offset) { viewPoint in
                        handleTap(at: viewPoint, frame: frame, viewSize: geo.size)
                    } onPan: { delta in
                        // 平移钳制：画面不越出视图
                        var newOffset = CGSize(width: offset.width + delta.width,
                                               height: offset.height + delta.height)
                        let maxDX = max(0, geo.size.width * (zoom - 1) / 2)
                        let maxDY = max(0, geo.size.height * (zoom - 1) / 2)
                        newOffset.width = min(max(newOffset.width, -maxDX), maxDX)
                        newOffset.height = min(max(newOffset.height, -maxDY), maxDY)
                        offset = newOffset
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
                    PointOverlay(frameSize: CGSize(width: frame.width, height: frame.height), viewSize: geo.size, zoom: zoom, offset: offset)
                    crosshairOverlay(geo: geo, frame: frame)
                } else if appState.simulatorWindow != nil {
                    connectingState
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusCanvas))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusCanvas)
                    .stroke(hoverLocation != nil ? DesignTokens.borderStrong : DesignTokens.border, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                captionBar.padding(.horizontal, 12).padding(.bottom, 10)
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

    // MARK: - 图注条(取代 v3 的三个浮动 chip)

    /// 画布底部的单条图注:左 = 设备与状态,右 = 缩放;全 mono,印刷线分隔
    private var captionBar: some View {
        HStack(spacing: 10) {
            deviceReadout
            if appState.clickEngine.isRunning {
                loopReadout
            }
            Spacer(minLength: 0)
            zoomControl
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: DesignTokens.captionBarHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusPanel)
                .fill(DesignTokens.bgCardRaised.opacity(0.94))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusPanel)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }

    /// 设备读数:状态点 + 设备名(mono)+ 状态(mono)
    private var deviceReadout: some View {
        HStack(spacing: 7) {
            if let window = appState.simulatorWindow {
                Controls.StatusDot(color: DesignTokens.ok, pulsing: true)
                Text(window.title)
                    .font(DesignTokens.mono(11, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                Text("已启动")
                    .font(DesignTokens.mono(10, weight: .medium))
                    .foregroundStyle(DesignTokens.ok)
            } else {
                Controls.StatusDot(color: DesignTokens.off)
                Text("未连接")
                    .font(DesignTokens.mono(11, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("设备状态")
    }

    /// 运行轮次:mono 读数(录制色,运行时唯一的醒目数据)
    private var loopReadout: some View {
        HStack(spacing: 5) {
            Controls.StatusDot(color: DesignTokens.record, pulsing: true)
            Text("第 \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮 · \(appState.clickPoints.count) 点")
                .font(DesignTokens.mono(10, weight: .medium))
                .foregroundStyle(DesignTokens.record)
                .contentTransition(.numericText())
                .animation(DesignTokens.quick, value: appState.clickEngine.currentLoop)
        }
        .accessibilityElement(children: .ignore)
    }

    // MARK: - 缩放控制(细线 + mono 读数)

    private var zoomControl: some View {
        HStack(spacing: 6) {
            Button {
                zoom = max(zoom / 1.25, 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("缩小")

            Slider(value: $zoom, in: 1...4, step: 0.25)
                .tint(DesignTokens.ink)
                .frame(width: 88)
                .controlSize(.mini)

            Button {
                zoom = min(zoom * 1.25, 4)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("放大")

            Rectangle()
                .fill(DesignTokens.border)
                .frame(width: 1, height: 14)

            ForEach([1.0, 2.0, 4.0], id: \.self) { level in
                Button {
                    withAnimation(DesignTokens.quick) {
                        zoom = level
                        offset = .zero
                    }
                } label: {
                    Text("\(Int(level))×")
                        .font(DesignTokens.mono(9, weight: .semibold))
                        .foregroundStyle(abs(zoom - level) < 0.01 ? DesignTokens.ink : DesignTokens.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            if abs(zoom - level) < 0.01 {
                                RoundedRectangle(cornerRadius: 2).fill(DesignTokens.bgSunken)
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
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("适应窗口")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("缩放控制")
    }

    // MARK: - 状态占位

    private var connectingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在连接镜像…")
                .font(DesignTokens.ui(12))
                .foregroundStyle(DesignTokens.textSecondary)
                .lineSpacing(2)
        }
    }

    /// 空态:serif 引导(22)+ sans 说明 + 次级按钮 —— CJK 行高 ≥1.3
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(DesignTokens.borderStrong)
            VStack(spacing: 6) {
                Text("尚未连接模拟器")
                    .font(DesignTokens.display(22, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineSpacing(4)
                Text("从左上角选择或启动一台模拟器,镜像将出现在这里")
                    .font(DesignTokens.ui(12))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineSpacing(3)
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
            RoundedRectangle(cornerRadius: DesignTokens.radiusCanvas)
                .stroke(DesignTokens.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .padding(1)
        )
    }

    // MARK: - 十字准星

    private func crosshairOverlay(geo: GeometryProxy, frame: CGImage) -> some View {
        ZStack {
            if let h = hoverLocation, !appState.clickEngine.isRunning {
                Rectangle()
                    .fill(DesignTokens.ink.opacity(0.25))
                    .frame(width: 1)
                    .frame(height: geo.size.height)
                    .position(x: h.x, y: geo.size.height / 2)
                Rectangle()
                    .fill(DesignTokens.ink.opacity(0.25))
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
                    // 墨底纸字小片:像胶片时间码,不套白框
                    Text(String(format: "x %.3f · y %.3f", rel.x, rel.y))
                        .font(DesignTokens.mono(10, weight: .medium))
                        .foregroundStyle(DesignTokens.paper)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignTokens.ink.opacity(0.88))
                        )
                        .position(
                            x: min(max(h.x + 14, 62), max(geo.size.width - 62, 62)),
                            y: max(h.y - 18, 24)
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
              !appState.aiAgent.isRunning,
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
    /// 帧尺寸（Equatable，避免每帧因 CGImage 引用变化重算子视图）
    let frameSize: CGSize
    let viewSize: CGSize
    let zoom: CGFloat
    let offset: CGSize

    var body: some View {
        let contentInFrame = appState.windowLocator.contentRectNormalizedInFrame()

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
                .foregroundStyle(DesignTokens.ink)
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
        .accessibilityLabel(point.label)
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
    let zoom: CGFloat
    let offset: CGSize
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
        nsView.applyTransform(zoom: zoom, offset: offset)
    }
}

final class FrameLayerView: NSView {
    var frameImage: CGImage? {
        didSet {
            layer?.contents = frameImage
        }
    }

    /// 应用缩放/平移（以视图中心为基准；layer 坐标 y 向上，offset y 取反）
    func applyTransform(zoom: CGFloat, offset: CGSize) {
        guard let layer, zoom > 0 else { return }
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, offset.width, -offset.height, 0)
        t = CATransform3DScale(t, zoom, zoom, 1)
        layer.transform = t
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
        layer?.backgroundColor = NSColor(hex: 0xEBE7DE).cgColor
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
        // 双击的第二击（复位缩放）不产生点位
        if event.clickCount == 2 { return }
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
