import SwiftUI

/// 左侧栏：品牌头、设备分组列表、权限状态、全局热键
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            brandHeader

            if appState.devices.isEmpty {
                noDevicesView
            } else {
                deviceList
            }

            Divider()
                .overlay(DesignTokens.borderCard)

            permissionSection
            Divider()
                .overlay(DesignTokens.borderCard)
            hotKeyRow
        }
        .frame(width: DesignTokens.sidebarWidth)
        .background(sidebarBackground)
        .onAppear {
            appState.refreshWindow()
        }
    }

    // MARK: - 品牌头

    private var brandHeader: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.brandGradient)
                .frame(width: 24, height: 24)
                .overlay {
                    Text("千")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("千手 Qianshou")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                Text("iOS Simulator Automation")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var sidebarBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0D1526), Color(hex: 0x0A101D)],
                           startPoint: .top, endPoint: .bottom)
            DesignTokens.brandGradient.opacity(0.04)
        }
    }

    // MARK: - 设备列表

    private var deviceList: some View {
        let booted = appState.devices.filter(\.isBooted)
        let shutdown = appState.devices.filter { !$0.isBooted }

        return List(selection: $appState.selectedDevice) {
            if !booted.isEmpty {
                Section {
                    ForEach(booted) { DeviceRow(device: $0) }
                } header: {
                    sectionHeader("已启动", count: booted.count)
                }
            }
            if !shutdown.isEmpty {
                Section {
                    ForEach(shutdown) { DeviceRow(device: $0) }
                } header: {
                    sectionHeader("已关机", count: shutdown.count)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(DesignTokens.bgCardRaised))
        }
        .textCase(nil)
    }

    private var noDevicesView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "iphone.slash")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.textTertiary)
            Text("未检测到模拟器")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("确认 Xcode 已安装并打开 Simulator")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.textTertiary)
                .multilineTextAlignment(.center)
            Button {
                Task { await appState.refreshDevices() }
            } label: {
                Label("刷新列表", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - 权限与热键

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            permissionRow(ok: appState.screenCapturePermission,
                          label: "屏幕录制",
                          systemImage: "display",
                          settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            permissionRow(ok: appState.accessibilityPermission,
                          label: "辅助功能",
                          systemImage: "cursorarrow.click",
                          settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
        .padding(10)
    }

    private func permissionRow(ok: Bool, label: String, systemImage: String, settingsURL: String) -> some View {
        Button {
            if let url = URL(string: settingsURL) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(ok ? DesignTokens.ok : DesignTokens.err)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill((ok ? DesignTokens.ok : DesignTokens.err).opacity(0.15))
                    )
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ok ? DesignTokens.ok : DesignTokens.err)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(ok ? "已授权" : "点击前往系统设置授权")
    }

    private var hotKeyRow: some View {
        HStack(spacing: 8) {
            Text("F8")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(DesignTokens.bgCardRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(DesignTokens.borderCard, lineWidth: 1)
                        )
                )
            Text("全局启停连点")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { appState.hotKeyEnabled },
                set: { appState.setHotKey(enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - 设备行

private struct DeviceRow: View {
    @EnvironmentObject private var appState: AppState
    let device: SimulatorDevice

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(isBooted: device.isBooted)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1)
                Text(shortUDID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .tag(device)
        .contextMenu {
            if !device.isBooted {
                Button("启动") { Task { await appState.boot(device) } }
            }
            Button("关机") { Task { await appState.shutdown(device) } }
            Button("复制 UDID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.udid, forType: .string)
            }
        }
    }

    private var shortUDID: String {
        String(device.udid.suffix(4)).uppercased()
    }
}
