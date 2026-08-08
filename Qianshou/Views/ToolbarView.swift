import SwiftUI

/// 顶部工具栏 v2 —— 精简为「品牌 + 设备 + 命令面板」
///
/// v1 的模式切换、AI 驾驶 popover 已移入右侧活动侧栏;
/// 权限状态、WDA 状态、F8 热键移入底部遥测条(StatusBarView)。
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
        .padding(.horizontal, 14)
        .frame(height: DesignTokens.toolbarHeight)
        .background(DesignTokens.bgCard)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)
        }
    }

    // MARK: - 品牌(扁平,去渐变)

    private var brandMark: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.accent)
                .frame(width: 24, height: 24)
                .overlay {
                    Text("千")
                        .font(DesignTokens.ui(13, weight: .bold))
                        .foregroundStyle(Color(hex: 0x06121C))
                }
            VStack(alignment: .leading, spacing: 0) {
                Text("千手")
                    .font(DesignTokens.ui(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                Text("QIANSHOU")
                    .font(DesignTokens.mono(8, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("千手 Qianshou")
    }

    // MARK: - 设备菜单

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
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.system(size: 12))
                Text(appState.selectedDevice?.name ?? "选择设备")
                    .font(DesignTokens.ui(12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .foregroundStyle(DesignTokens.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.bgCardRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignTokens.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("选择模拟器设备")
    }

    // MARK: - 命令面板入口

    private var commandButton: some View {
        Button {
            showCommandPalette = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "command")
                    .font(.system(size: 11))
                Text("命令")
                    .font(DesignTokens.ui(11, weight: .medium))
                Text("⌘K")
                    .font(DesignTokens.mono(10, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .foregroundStyle(DesignTokens.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.bgCardRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignTokens.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .help("命令面板(⌘K)")
        .accessibilityLabel("打开命令面板")
    }
}
