import SwiftUI

/// AI 驾驶面板 v4 —— 执行流 + 三态输入,accent 只跟随当前焦点元素
///
/// 交互逻辑(v2 已定,零改动):
/// - 独立成屏,不再遮挡镜像;输入/步骤流/设置纵向排布
/// - 三种输入态(目标 / 补充指令 / 回答问题)按运行状态自动切换
/// - 主 CTA 只有一个:开始执行;停止为次级危险操作
/// 排版改动:面板标题移入侧栏目录(TOC),此处只保留状态行;
/// 步骤图标空闲时不着色,执行中当前步用 accentText(accent 每屏 ≤2)。
struct AIPilotPanel: View {
    @EnvironmentObject private var appState: AppState
    @State private var goal = ""
    @State private var supplementText = ""
    @State private var answerText = ""
    @State private var showSettings = false

    private var isRunning: Bool { appState.aiAgent.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.space12) {
                    if let image = lastScreenshotImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 132)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPanel))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.radiusPanel)
                                    .stroke(DesignTokens.border, lineWidth: 1)
                            )
                    }
                    stepsFlow
                }
                .padding(DesignTokens.space12)
            }

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            inputArea
                .padding(DesignTokens.space12)

            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)

            settingsRow
                .padding(DesignTokens.space12)
        }
    }

    // MARK: - 状态行(标题在侧栏目录,此处只读状态)

    private var statusRow: some View {
        HStack(spacing: 8) {
            Controls.StatusDot(color: isRunning ? DesignTokens.ok : DesignTokens.off, pulsing: isRunning)
            Text(isRunning ? "执行中" : "待命")
                .font(DesignTokens.ui(12, weight: .semibold))
                .foregroundStyle(isRunning ? DesignTokens.ok : DesignTokens.textSecondary)
                .lineSpacing(2)
            if isRunning, !appState.aiAgent.steps.isEmpty {
                Text("\(appState.aiAgent.steps.count) 步")
                    .font(DesignTokens.mono(10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
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
        .padding(.horizontal, DesignTokens.space12)
        .padding(.vertical, 9)
    }

    // MARK: - 执行流

    private var stepsFlow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Controls.EditorialSection(title: "执行流", note: "STEPS")

            if !appState.aiAgent.steps.isEmpty {
                ForEach(Array(appState.aiAgent.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step: step, isCurrent: isRunning && index == appState.aiAgent.steps.count - 1)
                }
            }
            if isRunning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("AI 思考中…")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineSpacing(2)
                }
                .padding(.top, 2)
            } else if appState.aiAgent.steps.isEmpty {
                Text("描述目标后开始执行,AI 将自主操作模拟器")
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
            }
            if let summary = appState.aiAgent.finalSummary {
                Text("结果:\(summary)")
                    .font(DesignTokens.ui(10, weight: .medium))
                    .foregroundStyle(DesignTokens.ok)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(step: AIAgent.Step, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: step.isAction ? "cursorarrow.click" : "sparkles")
                .font(.system(size: 9))
                .foregroundStyle(isCurrent
                                 ? DesignTokens.accentText
                                 : (step.isAction ? DesignTokens.textSecondary : DesignTokens.textTertiary))
                .frame(width: 14)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.summary)
                    .font(DesignTokens.ui(11))
                    .foregroundStyle(isCurrent ? DesignTokens.ink : DesignTokens.textPrimary)
                    .lineSpacing(3)
                    .lineLimit(2)
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

    // MARK: - 输入区(三态自动切换)

    @ViewBuilder
    private var inputArea: some View {
        if let question = appState.aiAgent.pendingQuestion {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 提问:\(question)")
                    .font(DesignTokens.ui(11, weight: .medium))
                    .foregroundStyle(DesignTokens.warn)
                    .lineSpacing(3)
                HStack(spacing: 6) {
                    Controls.EditorialField(placeholder: "输入你的回答…", text: $answerText,
                                            onSubmit: { submitAnswer() })
                    Button("发送") { submitAnswer() }
                        .buttonStyle(Controls.SuccessButtonStyle())
                        .controlSize(.small)
                }
            }
        } else if isRunning {
            VStack(alignment: .leading, spacing: 6) {
                Text("手动补充:随时插入指令干预执行")
                    .font(DesignTokens.ui(10))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .lineSpacing(2)
                HStack(spacing: 6) {
                    Controls.EditorialField(placeholder: "如:先点返回,再输入 123456…", text: $supplementText,
                                            onSubmit: { submitSupplement() })
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
                    .lineSpacing(2)
                // 预置任务模板（一键填充目标）
                HStack(spacing: 6) {
                    ForEach(AITaskTemplate.all) { template in
                        Button {
                            goal = template.prompt
                        } label: {
                            Text(template.title)
                                .font(DesignTokens.ui(10, weight: .medium))
                                .foregroundStyle(DesignTokens.accentText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                                        .fill(DesignTokens.accentDim)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(template.prompt)
                    }
                }
                Controls.EditorialField(placeholder: "如:打开设置 → 开启深色模式", text: $goal,
                                        onSubmit: { submitGoal() })
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
                .opacity(goal.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                if appState.aiAPIKey.isEmpty {
                    Text("未配置 API Key(⚙ 设置中填写)")
                        .font(DesignTokens.ui(10))
                        .foregroundStyle(DesignTokens.err)
                        .lineSpacing(2)
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
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text("模型与密钥")
                        .font(DesignTokens.ui(11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineSpacing(2)
                    Spacer()
                    Text(appState.aiAPIKey.isEmpty ? "未配置" : "已配置")
                        .font(DesignTokens.mono(9, weight: .medium))
                        .foregroundStyle(appState.aiAPIKey.isEmpty ? DesignTokens.err : DesignTokens.ok)
                    Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showSettings {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Anthropic API Key", text: $appState.aiAPIKey)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.mono(11))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                                .fill(DesignTokens.bgSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
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


/// AI 预置任务模板（一键填充目标）
struct AITaskTemplate: Identifiable {
    let id: String
    let title: String
    let prompt: String

    static let all: [AITaskTemplate] = [
        AITaskTemplate(
            id: "smoke",
            title: "冒烟测试",
            prompt: "对当前 App 做一次冒烟测试：依次点击屏幕顶部、中部、底部的主要区域，每个区域点击后观察是否有明显响应（页面变化或高亮），最后回到主屏幕并总结测试结果。"
        ),
        AITaskTemplate(
            id: "browse",
            title: "遍历页面",
            prompt: "从当前页面开始逐层遍历：点击每个可见的主要入口进入子页面，观察内容后返回，继续下一个入口。记录访问过的页面清单。"
        ),
        AITaskTemplate(
            id: "darkmode",
            title: "开启深色模式",
            prompt: "打开设置 App，进入「显示与亮度」，找到深色模式选项并开启它，然后返回主屏幕。"
        ),
        AITaskTemplate(
            id: "form",
            title: "表单填写",
            prompt: "在当前页面找到输入框并依次聚焦，用测试数据填写每个字段（姓名: Test User, 邮箱: test@example.com, 电话: 13800000000），最后点击提交或完成按钮。"
        ),
    ]
}
