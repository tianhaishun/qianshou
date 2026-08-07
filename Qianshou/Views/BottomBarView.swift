import SwiftUI

/// 底部浮动玻璃操作条：状态 + 主操作 + 配置入口
/// 连点模式：点位状态 + 开始/停止连点 + ⚙
/// 录制模式：录制/停止 + 回放上次 + ⚙（序列管理）
struct BottomBarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showConfig = false

    var body: some View {
        HStack(spacing: 10) {
            statusChip

            Spacer()

            switch appState.mode {
            case .clicker:
                clickActions
            case .recorder:
                recordActions
            }

            Spacer()

            Button {
                showConfig.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(showConfig ? DesignTokens.brandBright : DesignTokens.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(showConfig ? DesignTokens.brandTint : DesignTokens.bgCardRaised))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showConfig, arrowEdge: .bottom) {
                ConfigPanelView()
                    .environmentObject(appState)
                    .frame(width: 340, height: 380)
            }
            .help("配置")
            .accessibilityLabel("打开配置")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignTokens.borderCard, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 6)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    // MARK: - 状态 chip

    private var statusChip: some View {
        HStack(spacing: 6) {
            switch appState.mode {
            case .clicker:
                if appState.clickEngine.isRunning {
                    Circle()
                        .fill(DesignTokens.err)
                        .frame(width: 7, height: 7)
                    Text("连点中 · \(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignTokens.textPrimary)
                } else {
                    Text("\(appState.clickPoints.count) 个点位")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            case .recorder:
                if appState.recorder.isRecording {
                    Circle()
                        .fill(DesignTokens.record)
                        .frame(width: 7, height: 7)
                        .shadow(color: DesignTokens.record.opacity(0.7), radius: 3)
                    Text("录制中 · \(appState.recorder.recordedCount) 次")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignTokens.textPrimary)
                } else if appState.player.isPlaying {
                    Text("回放中…")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    Text("\(appState.savedSequences.count) 个序列")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(DesignTokens.bgSunken))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前状态")
    }

    // MARK: - 连点操作

    private var clickActions: some View {
        HStack(spacing: 8) {
            if appState.clickEngine.isRunning {
                Button {
                    appState.stopClicking()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FlatTintButtonStyle(color: DesignTokens.err))
            } else {
                Button {
                    appState.startClicking()
                } label: {
                    Label("开始连点", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(appState.clickPoints.isEmpty
                          || appState.player.isPlaying
                          || appState.recorder.isRecording)
                .opacity(appState.clickPoints.isEmpty ? 0.45 : 1)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    // MARK: - 录制操作

    private var recordActions: some View {
        HStack(spacing: 8) {
            if appState.recorder.isRecording {
                Button {
                    appState.stopRecording()
                } label: {
                    Label("停止录制", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FlatTintButtonStyle(color: DesignTokens.record))
            } else {
                Button {
                    appState.startRecording()
                } label: {
                    Label("开始录制", systemImage: "record.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FlatTintButtonStyle(color: DesignTokens.brandBright))
                .disabled(appState.player.isPlaying || appState.clickEngine.isRunning)
            }

            if appState.lastRecordedSequence != nil || !appState.savedSequences.isEmpty {
                Button {
                    if let seq = appState.lastRecordedSequence ?? appState.savedSequences.first {
                        appState.playSequence(seq)
                    }
                } label: {
                    Label("回放", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .buttonStyle(FlatTintButtonStyle(color: DesignTokens.ok))
                .disabled(appState.player.isPlaying || appState.clickEngine.isRunning || appState.recorder.isRecording)
            }
        }
    }
}

/// 主按钮样式：品牌渐变填充 + 发光阴影 + 按下缩放
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(DesignTokens.brandGradient)
                    .shadow(color: DesignTokens.brandGlow, radius: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 纯色填充按钮样式（录制/停止/回放）
struct FlatTintButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
