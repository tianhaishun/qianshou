import SwiftUI

/// 录制回放面板 v4 —— 录制 = 实心 REC(record 色 + 纸字),序列 = 平铺行 + 时间轴
///
/// 交互逻辑(v2 已定,零改动):
/// - 每条序列新增可视化时间轴:每个动作按 offsetMs 落位,点击/拖动一目了然
/// - 录制控制收敛:录制中 = 停止(唯一主操作),空闲 = 开始录制
/// - 回放入口在序列行内,不占用面板级 CTA
/// 排版改动:录制状态行去方框;时间轴圆点从 accent 改墨色(accent 让位给
/// 侧栏选中态与行内回放按钮,每屏 ≤2)。
struct RecorderPanel: View {
    @EnvironmentObject private var appState: AppState

    private var isRecording: Bool { appState.recorder.isRecording }
    private var locked: Bool { appState.clickEngine.isRunning || appState.player.isPlaying }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.space20) {
                    recordSection
                    sequencesSection
                }
                .padding(DesignTokens.space16)
            }

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            recordAction
                .padding(DesignTokens.space16)
        }
    }

    // MARK: - 录制状态

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Controls.EditorialSection(title: "录制", note: "RECORD")

            HStack(spacing: 10) {
                Controls.StatusDot(
                    color: isRecording ? DesignTokens.record : DesignTokens.off,
                    pulsing: isRecording
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRecording ? "录制中" : "待命")
                        .font(DesignTokens.ui(12, weight: .semibold))
                        .foregroundStyle(isRecording ? DesignTokens.record : DesignTokens.textSecondary)
                        .lineSpacing(2)
                    Text(isRecording ? "已捕获操作,点击「停止并保存」生成序列" : "点击「开始录制」后,操作模拟器即可捕获")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineSpacing(3)
                }
                Spacer()
                if isRecording {
                    Text("\(appState.recorder.recordedCount) 次")
                        .font(DesignTokens.mono(13, weight: .semibold))
                        .foregroundStyle(DesignTokens.record)
                        .contentTransition(.numericText())
                        .animation(DesignTokens.quick, value: appState.recorder.recordedCount)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 序列列表 + 时间轴

    private var sequencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Controls.EditorialSection(title: "序列", note: "SEQUENCES", count: appState.savedSequences.count)

            if appState.savedSequences.isEmpty {
                Text("录制完成后自动保存为 JSON")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.savedSequences, id: \.self) { seq in
                        SequenceRow(sequence: seq)
                    }
                }
            }

            Button("打开序列文件夹") {
                if let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                          in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("QianShou/sequences", isDirectory: true) {
                    NSWorkspace.shared.open(dir)
                }
            }
            .buttonStyle(Controls.PlainButtonStyle(tint: DesignTokens.textTertiary))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - 录制主操作(空闲与录制中同为实心 REC)

    private var recordAction: some View {
        Group {
            if isRecording {
                Button {
                    appState.stopRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                        Text("停止并保存")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Controls.StopButtonStyle(color: DesignTokens.record))
            } else {
                Button {
                    appState.startRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 12))
                        Text("开始录制")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Controls.StopButtonStyle(color: DesignTokens.record))
                .disabled(locked)
                .opacity(locked ? 0.4 : 1)
            }
        }
        .help(isRecording ? "停止并保存序列" : "开始录制(操作模拟器即可捕获)")
        .accessibilityLabel(isRecording ? "停止并保存" : "开始录制")
    }
}

// MARK: - 序列行(含时间轴)

/// 一条序列:名称 + 时长读数 + 动作时间轴 + 回放/删除
private struct SequenceRow: View {
    @EnvironmentObject private var appState: AppState
    let sequence: ClickSequence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sequence.name)
                        .font(DesignTokens.ui(12, weight: .medium))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                    Text(String(format: "%.1f s · %d 动作", Double(sequence.durationMs) / 1000, sequence.points.count))
                        .font(DesignTokens.mono(9))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                Spacer()
                Button {
                    appState.playSequence(sequence)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(DesignTokens.accent))
                }
                .buttonStyle(.plain)
                .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
                .help("回放 \(sequence.name)")
                .accessibilityLabel("回放 \(sequence.name)")
                Button {
                    appState.deleteSequence(sequence)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("删除 \(sequence.name)")
                .accessibilityLabel("删除 \(sequence.name)")
            }

            SequenceTimeline(sequence: sequence)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusPanel)
                .fill(DesignTokens.bgCardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusPanel)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }
}

/// 序列时间轴:动作按 offsetMs 落位,click = 墨色圆点,drag = 琥珀横条
private struct SequenceTimeline: View {
    let sequence: ClickSequence

    private var totalMs: Double { max(Double(sequence.durationMs), 1) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                // 基线(印刷线)
                Rectangle()
                    .fill(DesignTokens.borderStrong)
                    .frame(height: 1)
                    .position(x: width / 2, y: 10)

                ForEach(Array(sequence.points.enumerated()), id: \.offset) { index, point in
                    let x = min(max(CGFloat(point.offsetMs) / totalMs * width, 7), width - 7)
                    if point.kind == .drag, let ex = point.endX, let ey = point.endY {
                        let len = min(max(CGFloat(point.durationMs ?? 0) / totalMs * width, 6), 26)
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(DesignTokens.warn)
                                .frame(width: max(len - 6, 2), height: 2)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(DesignTokens.warn)
                        }
                        .position(x: x, y: 10)
                        .help("拖动 #\(index + 1) → (\(String(format: "%.2f", ex)), \(String(format: "%.2f", ey)))")
                    } else {
                        Circle()
                            .fill(DesignTokens.ink)
                            .frame(width: 4, height: 4)
                            .position(x: x, y: 10)
                            .help("点击 #\(index + 1) · \(point.offsetMs) ms")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 20)
        }
        .frame(height: 20)
        .overlay(alignment: .bottomTrailing) {
            Text(String(format: "%.1fs", totalMs / 1000))
                .font(DesignTokens.mono(8))
                .foregroundStyle(DesignTokens.textTertiary)
                .offset(y: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sequence.name),共 \(sequence.points.count) 个动作,时长 \(Int(totalMs)) 毫秒")
    }
}
