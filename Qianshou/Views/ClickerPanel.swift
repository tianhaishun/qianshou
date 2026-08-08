import SwiftUI

/// 连点面板 v2 —— 取代 v1 ConfigPanel 的连点分支
///
/// 交互逻辑重构:
/// - 点位行坐标实时跟随画布拖拽更新
/// - 主操作收敛为单一 CTA:开始/停止连点(空格)
/// - 清空点位为次级操作,运行中整体锁定
struct ClickerPanel: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var pointsFocused: Bool

    private var isRunning: Bool { appState.clickEngine.isRunning }
    private var locked: Bool { isRunning || appState.player.isPlaying || appState.recorder.isRecording }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pointsSection
                    timingSection
                }
                .padding(14)
            }

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            primaryAction
                .padding(14)
        }
    }

    // MARK: - 点位

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Controls.SectionHeader(title: "点位", count: appState.clickPoints.count, accent: !appState.clickPoints.isEmpty)

            if appState.clickPoints.isEmpty {
                Text("点击镜像画面添加点位,悬停显示准星")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(DesignTokens.bgSunken.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(DesignTokens.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                        pointRow(index: index, point: point)
                        if index < appState.clickPoints.count - 1 {
                            Rectangle()
                                .fill(DesignTokens.border)
                                .frame(height: 1)
                                .padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(DesignTokens.bgSunken.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )

                HStack {
                    Text("提示:可直接拖拽画布上的点位微调")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Button("清空") {
                        appState.clearClickPoints()
                    }
                    .buttonStyle(Controls.PlainButtonStyle(tint: DesignTokens.textTertiary))
                    .disabled(locked)
                }
            }
        }
    }

    private func pointRow(index: Int, point: ClickPoint) -> some View {
        HStack(spacing: 9) {
            Text("\(index + 1)")
                .font(DesignTokens.mono(9, weight: .bold))
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(DesignTokens.accentDim))
                .overlay(Circle().stroke(DesignTokens.accentBorder, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(point.label.isEmpty ? "点 \(index + 1)" : point.label)
                    .font(DesignTokens.ui(11, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1)
                Text(String(format: "x %.3f · y %.3f", point.x, point.y))
                    .font(DesignTokens.mono(10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer()
            Button {
                appState.removeClickPoint(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(DesignTokens.bgCardRaised))
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("删除点位 \(index + 1)")
        }
        .padding(.vertical, 6)
    }

    // MARK: - 时序

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Controls.SectionHeader(title: "时序")
            Controls.MetricSlider(
                label: "点间隔",
                value: Binding(get: { appState.clickIntervalMs },
                               set: { appState.clickIntervalMs = $0 }),
                range: 50...5000, step: 50,
                display: "\(Int(appState.clickIntervalMs)) ms"
            )
            Controls.MetricSlider(
                label: "轮间隔",
                value: Binding(get: { appState.clickLoopIntervalMs },
                               set: { appState.clickLoopIntervalMs = $0 }),
                range: 0...5000, step: 100,
                display: "\(Int(appState.clickLoopIntervalMs)) ms"
            )
            HStack {
                Text("循环轮数")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Stepper(value: $appState.clickLoops, in: 1...999) {
                    Text(appState.clickLoops >= 999 ? "∞" : "\(appState.clickLoops)")
                        .font(DesignTokens.mono(12, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .frame(width: 30, alignment: .trailing)
                }
                .controlSize(.small)
            }
        }
        .disabled(locked)
    }

    // MARK: - 主操作

    private var primaryAction: some View {
        Group {
            if isRunning {
                Button {
                    appState.stopClicking()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                        Text("停止连点")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Controls.DangerButtonStyle())
            } else {
                Button {
                    appState.startClicking()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("开始连点")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Controls.PrimaryButtonStyle())
                .keyboardShortcut(.space, modifiers: [])
                .disabled(appState.clickPoints.isEmpty || appState.player.isPlaying || appState.recorder.isRecording)
                .opacity(appState.clickPoints.isEmpty ? 0.45 : 1)
            }
        }
        .help(isRunning ? "停止连点" : "开始连点(空格)")
        .accessibilityLabel(isRunning ? "停止连点" : "开始连点")
    }
}
