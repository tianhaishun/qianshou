import SwiftUI

/// 连点面板 v4 —— 排版:点位列表改为「目录行」,时序保持滑块 + mono 读数
///
/// 交互逻辑(v2 已定,零改动):
/// - 点位行坐标实时跟随画布拖拽更新
/// - 主操作收敛为单一 CTA:开始/停止连点(空格)
/// - 清空点位为次级操作,运行中整体锁定
/// 排版改动:序号从 accent 改回墨色(accent 让位给 CTA 与选中态);
/// 点位列表去方框,改为细线分隔的平铺行。
struct ClickerPanel: View {
    @EnvironmentObject private var appState: AppState

    private var isRunning: Bool { appState.clickEngine.isRunning }
    private var locked: Bool { isRunning || appState.player.isPlaying || appState.recorder.isRecording }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.space20) {
                    pointsSection
                    timingSection
                }
                .padding(DesignTokens.space16)
            }

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            primaryAction
                .padding(DesignTokens.space16)
        }
    }

    // MARK: - 点位(目录式平铺行)

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Controls.EditorialSection(title: "点位", note: "POINTS", count: appState.clickPoints.count)

            if appState.clickPoints.isEmpty {
                Text("点击镜像画面添加点位,悬停显示准星")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                        pointRow(index: index, point: point)
                        if index < appState.clickPoints.count - 1 {
                            Rectangle()
                                .fill(DesignTokens.border)
                                .frame(height: 1)
                                .padding(.leading, 26)
                        }
                    }
                }

                HStack {
                    Text("可直接拖拽画布上的点位微调")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineSpacing(2)
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
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
                .font(DesignTokens.mono(9, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: 16, alignment: .leading)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.label.isEmpty ? "点 \(index + 1)" : point.label)
                    .font(DesignTokens.ui(12, weight: .medium))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
                Text(String(format: "x %.3f · y %.3f", point.x, point.y))
                    .font(DesignTokens.mono(10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer(minLength: 0)
            Button {
                appState.removeClickPoint(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("删除点位 \(index + 1)")
            .padding(.top, 2)
        }
        .padding(.vertical, 7)
    }

    // MARK: - 时序

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Controls.EditorialSection(title: "时序", note: "TIMING")
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
                    .lineSpacing(2)
                Spacer()
                Stepper(value: $appState.clickLoops, in: 1...999) {
                    Text(appState.clickLoops >= 999 ? "∞" : "\(appState.clickLoops)")
                        .font(DesignTokens.mono(12, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(width: 30, alignment: .trailing)
                }
                .controlSize(.small)
            }
        }
        .disabled(locked)
    }

    // MARK: - 主操作(运行中 = 实心停止)

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
                .buttonStyle(Controls.StopButtonStyle())
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
                .opacity(appState.clickPoints.isEmpty ? 0.4 : 1)
            }
        }
        .help(isRunning ? "停止连点" : "开始连点(空格)")
        .accessibilityLabel(isRunning ? "停止连点" : "开始连点")
    }
}
