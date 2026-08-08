import SwiftUI

/// AI 驾驶面板 v2 —— 取代 v1 的 popover(AIPanelView)
///
/// 交互逻辑重构:
/// - 独立成屏,不再遮挡镜像;输入/步骤流/设置纵向排布
/// - 三种输入态(目标 / 补充指令 / 回答问题)按运行状态自动切换
/// - 主 CTA 只有一个:开始执行;停止为次级危险操作
struct AIPilotPanel: View {
    @EnvironmentObject private var appState: AppState
    @State private var goal = ""
    @State private var supplementText = ""
    @State private var answerText = ""
    @State private var showSettings = false

    private var isRunning: Bool { appState.aiAgent.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = lastScreenshotImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(DesignTokens.border, lineWidth: 1)
                            )
                    }
                    stepsFlow
                }
                .padding(12)
            }

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            inputArea
                .padding(12)

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            settingsRow
                .padding(12)
        }
    }

    // MARK: - 状态头

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Controls.StatusDot(color: isRunning ? DesignTokens.ok : DesignTokens.off, pulsing: isRunning)
            Text("AI 驾驶")
                .font(DesignTokens.ui(12, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
            Text(isRunning ? "执行中" : "待命")
                .font(DesignTokens.ui(10, weight: .medium))
                .foregroundStyle(isRunning ? DesignTokens.ok : DesignTokens.textTertiary)
            Spacer()
            if isRunning {
                Button {
                    appState.aiAgent.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(Controls.DangerButtonStyle())
                .controlSize(.small)
                .accessibilityLabel("停止 AI 驾驶")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - 步骤流

    private var stepsFlow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !appState.aiAgent.steps.isEmpty {
                ForEach(appState.aiAgent.steps) { step in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: step.isAction ? "cursorarrow.click" : "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(step.isAction ? DesignTokens.accent : DesignTokens.textTertiary)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.summary)
                                .font(DesignTokens.ui(11))
                                .foregroundStyle(DesignTokens.textPrimary)
                            if let detail = step.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(DesignTokens.mono(9))
                                    .foregroundStyle(DesignTokens.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            if isRunning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("AI 思考中…")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .padding(.top, 2)
            } else if appState.aiAgent.steps.isEmpty {
                Text("描述目标后开始执行,AI 将自主操作模拟器")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
            if let summary = appState.aiAgent.finalSummary {
                Text("结果:\(summary)")
                    .font(DesignTokens.ui(10, weight: .medium))
                    .foregroundStyle(DesignTokens.ok)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 输入区(三态自动切换)

    @ViewBuilder
    private var inputArea: some View {
        if let question = appState.aiAgent.pendingQuestion {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 提问:\(question)")
                    .font(DesignTokens.ui(11, weight: .medium))
                    .foregroundStyle(DesignTokens.warn)
                HStack(spacing: 6) {
                    TextField("输入你的回答…", text: $answerText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.ui(11))
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.bgSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignTokens.border, lineWidth: 1)
                        )
                        .onSubmit { submitAnswer() }
                    Button("发送") { submitAnswer() }
                        .buttonStyle(Controls.PrimaryButtonStyle(color: DesignTokens.ok))
                        .controlSize(.small)
                }
            }
        } else if isRunning {
            VStack(alignment: .leading, spacing: 6) {
                Text("手动补充:随时插入指令干预执行")
                    .font(DesignTokens.ui(10))
                    .foregroundStyle(DesignTokens.textTertiary)
                HStack(spacing: 6) {
                    TextField("如:先点返回,再输入 123456…", text: $supplementText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.ui(11))
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.bgSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignTokens.border, lineWidth: 1)
                        )
                        .onSubmit { submitSupplement() }
                    Button("插入") { submitSupplement() }
                        .buttonStyle(Controls.SecondaryButtonStyle())
                        .controlSize(.small)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("目标")
                    .font(DesignTokens.ui(11, weight: .semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                TextField("如:打开设置 → 开启深色模式", text: $goal)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.ui(12))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(DesignTokens.bgSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(DesignTokens.border, lineWidth: 1)
                    )
                    .onSubmit { submitGoal() }
                Button {
                    submitGoal()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("开始执行")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Controls.PrimaryButtonStyle())
                .disabled(goal.trimmingCharacters(in: .whitespaces).isEmpty || !appState.wdaRunning)
                .opacity(goal.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                if !appState.wdaRunning {
                    Text("WDA 未运行,无法执行(scripts/start_wda.sh)")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.err)
                }
            }
        }
    }

    // MARK: - 设置(可折叠)

    private var settingsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(DesignTokens.quick) {
                    showSettings.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                    Text("模型与密钥")
                        .font(DesignTokens.ui(11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Text(appState.aiAPIKey.isEmpty ? "未配置" : "已配置")
                        .font(DesignTokens.mono(9))
                        .foregroundStyle(appState.aiAPIKey.isEmpty ? DesignTokens.err : DesignTokens.ok)
                    Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showSettings {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Anthropic API Key", text: $appState.aiAPIKey)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.mono(11))
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.bgSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignTokens.border, lineWidth: 1)
                        )
                        .onChange(of: appState.aiAPIKey) { _, _ in appState.saveAISettings() }
                    Picker("模型", selection: $appState.aiModel) {
                        Text("Opus 4.8").tag("claude-opus-4-8")
                        Text("Sonnet 5").tag("claude-sonnet-5")
                        Text("Fable 5").tag("claude-fable-5")
                    }
                    .pickerStyle(.menu)
                    .font(DesignTokens.ui(11))
                    .onChange(of: appState.aiModel) { _, _ in appState.saveAISettings() }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 动作

    private var lastScreenshotImage: NSImage? {
        guard let b64 = appState.aiAgent.lastScreenshot,
              let data = Data(base64Encoded: b64) else { return nil }
        return NSImage(data: data)
    }

    private func submitGoal() {
        let text = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.aiAgent.run(goal: text, apiKey: appState.aiAPIKey, model: appState.aiModel)
        goal = ""
    }

    private func submitSupplement() {
        let text = supplementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.aiAgent.supplement(text)
        supplementText = ""
    }

    private func submitAnswer() {
        let text = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.aiAgent.answer(text)
        answerText = ""
    }
}
