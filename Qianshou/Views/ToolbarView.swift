import SwiftUI

/// 顶部工具栏：品牌、设备菜单、模式切换（⌘1/⌘2）、权限状态、F8 状态
struct ToolbarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            brandMark

            deviceMenu

            Spacer()

            modeButtons

            Divider()
                .frame(height: 18)
                .overlay(DesignTokens.borderCard)

            permissionStatus
            f8Status
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.borderCard)
                .frame(height: 1)
        }
    }

    // MARK: - 品牌

    private var brandMark: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.brandGradient)
                .frame(width: 22, height: 22)
                .overlay {
                    Text("千")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text("千手")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("千手 Qianshou")
    }

    // MARK: - 设备菜单

    private var deviceMenu: some View {
        Menu {
            // 已启动分组
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
                        Label("\(device.name)（启动）", systemImage: "power")
                    }
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
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .foregroundStyle(DesignTokens.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.bgCardRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.borderCard, lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("选择模拟器设备")
    }

    // MARK: - 模式切换

    private var modeButtons: some View {
        HStack(spacing: 3) {
            modeButton(title: "连点", systemImage: "cursorarrow.click.2",
                       isActive: appState.mode == .clicker,
                       shortcut: "1") {
                appState.mode = .clicker
            }
            modeButton(title: "录制", systemImage: "record.circle",
                       isActive: appState.mode == .recorder,
                       shortcut: "2") {
                appState.mode = .recorder
            }
        }
        .padding(3)
        .background(Capsule().fill(DesignTokens.bgSunken))
    }

    private func modeButton(title: String, systemImage: String, isActive: Bool, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text("⌘\(shortcut)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? .white.opacity(0.8) : DesignTokens.textTertiary)
            }
            .foregroundStyle(isActive ? .white : DesignTokens.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if isActive {
                    Capsule().fill(DesignTokens.brandGradient)
                }
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut == "1" ? .init("1", modifiers: .command) : .init("2", modifiers: .command))
        .accessibilityLabel("切换到\(title)模式")
    }

    // MARK: - 权限与热键

    private var permissionStatus: some View {
        HStack(spacing: 8) {
            statusIcon(ok: appState.screenCapturePermission, systemImage: "display")
                .help(appState.screenCapturePermission ? "屏幕录制已授权" : "屏幕录制未授权，点击打开系统设置")
                .onTapGesture {
                    if !appState.screenCapturePermission,
                       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            statusIcon(ok: appState.accessibilityPermission, systemImage: "cursorarrow.click")
                .help(appState.accessibilityPermission ? "辅助功能已授权" : "辅助功能未授权，点击打开系统设置")
                .onTapGesture {
                    if !appState.accessibilityPermission,
                       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
    }

    private func statusIcon(ok: Bool, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(ok ? DesignTokens.ok : DesignTokens.err)
            .frame(width: 24, height: 24)
            .background(
                Circle().fill((ok ? DesignTokens.ok : DesignTokens.err).opacity(0.12))
            )
    }

    private var f8Status: some View {
        HStack(spacing: 5) {
            Text("F8")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(appState.hotKeyEnabled ? DesignTokens.brandBright : DesignTokens.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(DesignTokens.bgCardRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(appState.hotKeyEnabled ? DesignTokens.brandBright.opacity(0.5) : DesignTokens.borderCard, lineWidth: 1)
                        )
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
