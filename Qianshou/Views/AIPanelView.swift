import SwiftUI

/// AI 驾驶面板：自然语言目标 → 自主操作；运行中可手动补充指令
struct AIPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var goal = ""
    @State private var supplementText = ""
    @State private var answerText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(DesignTokens.borderCard)

            // 截图预览
            if let b64 = appState.aiAgent.lastScreenshot,
               let data = Data(base64Encoded: b64),
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(DesignTokens.bgSunken)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(10)
            }

            // 步骤流
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.aiAgent.steps) { step in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: step.isAction ? "cursorarrow.click" : "sparkles")
                                    .font(.system(size: 9))
                                    .foregroundStyle(step.isAction ? DesignTokens.brandBright : DesignTokens.textTertiary)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(step.summary)
                                        .font(.system(size: 11))
                                        .foregroundStyle(DesignTokens.textPrimary)
                                    if let detail = step.detail, !detail.isEmpty {
                                        Text(detail)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(DesignTokens.textTertiary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .id(step.id)
                        }
                        if appState.aiAgent.isRunning {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text("AI 思考中…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: appState.aiAgent.steps.count) { _, _ in
                    if let last = appState.aiAgent.steps.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider().overlay(DesignTokens.borderCard)

            // 输入区：目标 / 补充指令 / 回答
            inputArea
        }
        .frame(width: 400, height: 560)
        .background(DesignTokens.bgBase)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.brandBright)
                Text("AI 驾驶")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(appState.aiAgent.isRunning ? "· 执行中" : "· 待命")
                    .font(.system(size: 10))
                    .foregroundStyle(appState.aiAgent.isRunning ? DesignTokens.ok : DesignTokens.textTertiary)
            }
            Spacer()
            if appState.aiAgent.isRunning {
                Button {
                    appState.aiAgent.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(FlatTintButtonStyle(color: DesignTokens.err))
                .controlSize(.small)
            }
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
        .padding(12)
    }

    @ViewBuilder
    private var inputArea: some View {
        if let question = appState.aiAgent.pendingQuestion {
            // ask_user：等待回答
            VStack(alignment: .leading, spacing: 6) {
                Text("🤔 \(question)")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.warn)
                HStack(spacing: 6) {
                    TextField("输入你的回答…", text: $answerText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(DesignTokens.bgSunken))
                        .onSubmit { submitAnswer() }
                    Button("发送") { submitAnswer() }
                        .buttonStyle(FlatTintButtonStyle(color: DesignTokens.ok))
                        .controlSize(.small)
                }
            }
            .padding(10)
        } else if appState.aiAgent.isRunning {
            // 手动补充模式：随时插入指令
            VStack(alignment: .leading, spacing: 6) {
                Text("手动补充：可随时插入指令干预执行")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
                HStack(spacing: 6) {
                    TextField("如：先点返回，然后输入 123456…", text: $supplementText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(DesignTokens.bgSunken))
                        .onSubmit { submitSupplement() }
                    Button("插入") { submitSupplement() }
                        .buttonStyle(FlatTintButtonStyle(color: DesignTokens.brandBright))
                        .controlSize(.small)
                }
            }
            .padding(10)
        } else {
            // 目标输入
            VStack(alignment: .leading, spacing: 6) {
                TextField("描述目标，如：打开设置 → 把深色模式打开", text: $goal)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(DesignTokens.bgSunken))
                    .onSubmit { submitGoal() }
                Button {
                    submitGoal()
                } label: {
                    Label("开始执行", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(goal.trimmingCharacters(in: .whitespaces).isEmpty || !appState.wdaRunning)
                if !appState.wdaRunning {
                    Text("WDA 未运行，无法执行（scripts/start_wda.sh）")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.err)
                }
                if let summary = appState.aiAgent.finalSummary {
                    Text("结果：\(summary)")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.ok)
                        .padding(.top, 2)
                }
            }
            .padding(10)
        }
    }

    private func submitGoal() {
        guard !goal.isEmpty else { return }
        appState.aiAgent.run(goal: goal, apiKey: appState.aiAPIKey, model: appState.aiModel)
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
