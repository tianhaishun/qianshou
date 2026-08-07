import SwiftUI

/// ⚙ 配置弹出层：点位列表（连点模式）+ 间隔/轮数 + 序列管理（录制模式）
struct ConfigPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(DesignTokens.borderCard)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch appState.mode {
                    case .clicker:
                        pointsSection
                        timingSection
                    case .recorder:
                        sequencesSection
                    }
                }
                .padding(14)
            }
        }
        .background(DesignTokens.bgBase)
    }

    private var header: some View {
        HStack {
            Text(appState.mode == .clicker ? "连点配置" : "录制与序列")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(DesignTokens.bgCardRaised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(14)
    }

    // MARK: - 点位列表

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("点位", count: appState.clickPoints.count)
            if appState.clickPoints.isEmpty {
                Text("点击镜像画面添加点位")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(appState.clickPoints.enumerated()), id: \.element.id) { index, point in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(DesignTokens.brandGradient))
                        Text("\(String(format: "%.2f", point.x)) · \(String(format: "%.2f", point.y))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer()
                        Button {
                            appState.removeClickPoint(at: IndexSet(integer: index))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除点位 \(index + 1)")
                    }
                    .padding(.vertical, 3)
                }
                Button("清空点位") {
                    appState.clearClickPoints()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.clickEngine.isRunning)
            }
        }
    }

    // MARK: - 参数

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("时序")
            configSlider(label: "点间隔",
                         value: Binding(get: { appState.clickIntervalMs },
                                        set: { appState.clickIntervalMs = $0 }),
                         range: 50...5000, step: 50,
                         display: "\(Int(appState.clickIntervalMs))ms")
            configSlider(label: "轮间隔",
                         value: Binding(get: { appState.clickLoopIntervalMs },
                                        set: { appState.clickLoopIntervalMs = $0 }),
                         range: 0...5000, step: 100,
                         display: "\(Int(appState.clickLoopIntervalMs))ms")
            HStack {
                Text("循环轮数")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Stepper(value: $appState.clickLoops, in: 1...999) {
                    Text(appState.clickLoops >= 999 ? "∞" : "\(appState.clickLoops)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .frame(width: 30, alignment: .trailing)
                }
                .controlSize(.small)
            }
        }
    }

    private func configSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, display: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text(display)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .contentTransition(.numericText())
            }
            Slider(value: value, in: range, step: step)
                .tint(DesignTokens.brandBright)
                .controlSize(.small)
        }
    }

    // MARK: - 序列

    private var sequencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("已保存序列", count: appState.savedSequences.count)
            if appState.savedSequences.isEmpty {
                Text("录制后自动保存为 JSON")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(appState.savedSequences, id: \.self) { seq in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(seq.name)
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(1)
                            Text("\(String(format: "%.1f", Double(seq.durationMs) / 1000))s · \(seq.points.count) 点")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        Spacer()
                        Button {
                            appState.playSequence(seq)
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.brandBright)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(DesignTokens.brandTint))
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
                        .accessibilityLabel("回放 \(seq.name)")
                        Button {
                            appState.deleteSequence(seq)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除 \(seq.name)")
                    }
                    .padding(.vertical, 3)
                }
            }
            Button("打开序列文件夹") {
                if let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                          in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("QianShou/sequences", isDirectory: true) {
                    NSWorkspace.shared.open(dir)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func sectionTitle(_ title: String, count: Int? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(DesignTokens.brandGradient))
            }
        }
    }
}
