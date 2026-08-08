import SwiftUI

/// 顶部工具栏 v4 —— 页眉:serif 品牌 + 设备 + ⌘K
///
/// v1 的模式切换、AI 驾驶 popover 已移入右侧活动侧栏;
/// 权限状态、WDA 状态、F8 热键移入底部遥测条(StatusBarView)。
/// 排版改动:品牌用 serif 17 + mono caps 8(tracking 0.12em)双行锁标,
/// 菜单与按钮默认无框,悬停才抬底(印刷页眉感,不画方框)。
struct ToolbarView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showCommandPalette: Bool

    var body: some View {
        HStack(spacing: 12) {
            brandMark
            deviceMenu
            Spacer()
            commandButton
        }
        .padding(.horizontal, DesignTokens.space16)
        .frame(height: DesignTokens.toolbarHeight)
        .background(DesignTokens.bgCard)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)
        }
    }

    // MARK: - 品牌(serif + mono caps 双行锁标)

    private var brandMark: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                .fill(DesignTokens.bgSunken)
                .frame(width: 24, height: 24)
                .overlay {
                    Text("千")
                        .font(DesignTokens.display(13, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("千手")
                    .font(DesignTokens.display(17, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineSpacing(2)
                Text("QIANSHOU")
                    .font(DesignTokens.caps(8))
                    .tracking(DesignTokens.capsTracking(for: 8))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("千手 Qianshou")
    }

    // MARK: - 设备菜单(默认无框,悬停抬底)

    private var deviceMenu: some View {
        Menu {
            let booted = appState.devices.filter(\.isBooted)
            let shutdown = appState.devices.filter { !$0.isBooted }
            if !booted.isEmpty {
                ForEach(booted) { device in
                    Button {
                        appState.selectedDevice = device
                        Task { await appState.startMirroring() }
                    } label: {
                        Label(device.name, systemImage: "iphone")
                    }
                }
                Divider()
            }
            if !shutdown.isEmpty {
                ForEach(shutdown) { device in
                    Button {
                        appState.selectedDevice = device
                        Task { await appState.boot(device) }
                    } label: {
                        Label("\(device.name)(启动)", systemImage: "power")
                    }
                }
            }
            Divider()
            Button("安装 App…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "app") ?? .application,
                                             .init(filenameExtension: "ipa") ?? .archive]
                panel.allowsMultipleSelection = false
                panel.message = "选择 .app 或 .ipa 安装到模拟器"
                if panel.runModal() == .OK, let url = panel.url {
                    Task { await appState.installAndLaunchApp(at: url) }
                }
            }
            Divider()
            Button("刷新列表") {
                Task { await appState.refreshDevices() }
            }
        } label: {
            ToolbarPill {
                HStack(spacing: 7) {
                    Image(systemName: "iphone")
                        .font(.system(size: 11))
                    Text(appState.selectedDevice?.name ?? "选择设备")
                        .font(DesignTokens.ui(12, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .foregroundStyle(DesignTokens.ink)
            }
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("选择模拟器设备")
    }

    // MARK: - 命令面板入口(⌘K)

    private var commandButton: some View {
        Button {
            showCommandPalette = true
        } label: {
            ToolbarPill {
                HStack(spacing: 8) {
                    Text("命令")
                        .font(DesignTokens.ui(12, weight: .medium))
                    Controls.KbdHint(text: "⌘K")
                }
                .foregroundStyle(DesignTokens.ink)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .help("命令面板(⌘K)")
        .accessibilityLabel("打开命令面板")
    }
}

/// 工具栏按钮衬底:默认无框,悬停抬底(印刷页眉感,文字永不降对比)
private struct ToolbarPill<Label: View>: View {
    @ViewBuilder var label: () -> Label
    @State private var hovering = false

    var body: some View {
        label()
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                    .fill(hovering ? DesignTokens.bgSunken.opacity(0.85) : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}
