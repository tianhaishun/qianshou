import SwiftUI

/// 底部遥测条 v4 —— 页脚(colophon):零方框,纯 mono 数据
///
/// 职责收敛为「状态读数」:活动状态灯 + mono 数据 + 权限/WDA/F8。
/// 排版改动:v3 的四个带框 chip(TelemetryChip)全部退役,
/// 改为 label + 值 的 mono 数据行,细竖线分隔(印刷页脚感)。
struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            activityReadout
            Spacer()
            telemetryRow
        }
        .padding(.horizontal, DesignTokens.space16)
        .frame(height: DesignTokens.statusBarHeight)
        .background(DesignTokens.bgCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)
        }
    }

    // MARK: - 活动读数

    private var activityReadout: some View {
        HStack(spacing: 8) {
            Controls.StatusDot(color: statusColor, pulsing: statusPulsing)
            Text(activityLabel)
                .font(DesignTokens.mono(11, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
            if let detail = statusDetail {
                Text(detail)
                    .font(DesignTokens.mono(10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activityLabel)
    }

    private var statusColor: Color {
        if appState.clickEngine.isRunning { return DesignTokens.record }
        if appState.recorder.isRecording { return DesignTokens.record }
        if appState.player.isPlaying { return DesignTokens.ok }
        if appState.aiAgent.isRunning { return DesignTokens.ok }
        return DesignTokens.off
    }

    private var statusPulsing: Bool {
        appState.clickEngine.isRunning || appState.recorder.isRecording || appState.aiAgent.isRunning
    }

    private var activityLabel: String {
        if appState.clickEngine.isRunning { return "连点中" }
        if appState.recorder.isRecording { return "录制中" }
        if appState.player.isPlaying { return "回放中" }
        if appState.aiAgent.isRunning { return "AI 驾驶中" }
        return "待命"
    }

    private var statusDetail: String? {
        if appState.clickEngine.isRunning {
            return "\(appState.clickEngine.currentLoop)/\(appState.clickEngine.totalLoops) 轮 · \(appState.clickPoints.count) 点"
        }
        if appState.recorder.isRecording {
            return "\(appState.recorder.recordedCount) 次操作"
        }
        if appState.player.isPlaying {
            return "\(appState.savedSequences.count) 个序列"
        }
        if appState.aiAgent.isRunning {
            return "\(appState.aiAgent.steps.count) 步"
        }
        return nil
    }

    // MARK: - 遥测数据行(label 三级 + 值墨色,细竖线分隔)

    private var telemetryRow: some View {
        HStack(spacing: 0) {
            datum(label: "镜像", value: appState.isMirroring ? "ON" : "OFF",
                  color: appState.isMirroring ? DesignTokens.ok : DesignTokens.textTertiary)
                .help(appState.isMirroring ? "镜像运行中" : "镜像未运行")
            separator
            datum(label: "WDA", value: appState.wdaRunning ? "ON" : "OFF",
                  color: appState.wdaRunning ? DesignTokens.ok : DesignTokens.err)
                .help(appState.wdaRunning ? "触摸注入服务运行中" : "触摸注入服务未运行(scripts/start_wda.sh)")
                .onTapGesture {
                    Task { await appState.ensureWDASession() }
                }
            separator
            datum(label: "录屏", value: appState.screenCapturePermission ? "OK" : "NO",
                  color: appState.screenCapturePermission ? DesignTokens.ok : DesignTokens.err)
                .help(appState.screenCapturePermission ? "屏幕录制已授权" : "屏幕录制未授权,点击打开系统设置")
                .onTapGesture {
                    if !appState.screenCapturePermission,
                       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            separator
            f8Toggle
        }
        .accessibilityElement(children: .contain)
    }

    private var separator: some View {
        Rectangle()
            .fill(DesignTokens.border)
            .frame(width: 1, height: 12)
            .padding(.horizontal, 9)
    }

    /// 单个数据项:label(mono 10 三级)+ 值(mono 10 medium)
    private func datum(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(DesignTokens.mono(10))
                .foregroundStyle(DesignTokens.textTertiary)
            Text(value)
                .font(DesignTokens.mono(10, weight: .medium))
                .foregroundStyle(color)
        }
        .contentShape(Rectangle())
    }

    // MARK: - F8 热键

    private var f8Toggle: some View {
        HStack(spacing: 7) {
            Controls.KbdHint(text: "F8", highlighted: appState.hotKeyEnabled)
            Toggle("", isOn: Binding(
                get: { appState.hotKeyEnabled },
                set: { appState.setHotKey(enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .accessibilityLabel("F8 全局启停连点")
        }
        .help("F8 全局启停连点")
    }
}
