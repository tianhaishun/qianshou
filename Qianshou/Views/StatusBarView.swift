import SwiftUI

/// 底部遥测条 v2 —— 取代 v1 的浮动玻璃操作条(BottomBarView)
///
/// 职责收敛为「状态读数」:活动状态灯 + mono 数据 + 权限/WDA/F8,
/// 不再承载操作按钮(操作已移入侧栏面板)。
struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            activityReadout
            Spacer()
            mirrorChip
            wdaChip
            permissionChip
            f8Toggle
        }
        .padding(.horizontal, 14)
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
                .foregroundStyle(DesignTokens.textPrimary)
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

    // MARK: - 状态 chip

    private var mirrorChip: some View {
        Controls.TelemetryChip(
            label: "镜像",
            value: appState.isMirroring ? "ON" : "OFF",
            dotColor: appState.isMirroring ? DesignTokens.ok : DesignTokens.off
        )
        .help(appState.isMirroring ? "镜像运行中" : "镜像未运行")
    }

    private var wdaChip: some View {
        Controls.TelemetryChip(
            label: "WDA",
            value: appState.wdaRunning ? "ON" : "OFF",
            dotColor: appState.wdaRunning ? DesignTokens.ok : DesignTokens.err
        )
        .help(appState.wdaRunning ? "触摸注入服务运行中" : "触摸注入服务未运行(scripts/start_wda.sh)")
        .onTapGesture {
            Task { await appState.ensureWDASession() }
        }
    }

    private var permissionChip: some View {
        Controls.TelemetryChip(
            label: "录屏",
            value: appState.screenCapturePermission ? "OK" : "NO",
            dotColor: appState.screenCapturePermission ? DesignTokens.ok : DesignTokens.err
        )
        .help(appState.screenCapturePermission ? "屏幕录制已授权" : "屏幕录制未授权,点击打开系统设置")
        .onTapGesture {
            if !appState.screenCapturePermission,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - F8 热键

    private var f8Toggle: some View {
        HStack(spacing: 6) {
            Text("F8")
                .font(DesignTokens.mono(10, weight: .bold))
                .foregroundStyle(appState.hotKeyEnabled ? DesignTokens.accent : DesignTokens.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.bgSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(appState.hotKeyEnabled ? DesignTokens.accentBorder : DesignTokens.border, lineWidth: 1)
                )
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
