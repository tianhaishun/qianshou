import SwiftUI

/// 左侧栏：模拟器列表 + 启停 + 权限状态
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedDevice) {
                ForEach(appState.devices) { device in
                    DeviceRow(device: device)
                        .tag(device)
                }
            }
            .listStyle(.sidebar)

            Divider()
            PermissionStatusBar()
        }
    }
}

private struct DeviceRow: View {
    @EnvironmentObject private var appState: AppState
    let device: SimulatorDevice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isBooted ? "iphone" : "iphone.slash")
                .foregroundStyle(device.isBooted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .lineLimit(1)
                Text(device.runtimeShort)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if device.isBooted {
                Button {
                    Task { await appState.shutdown(device) }
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("关机")
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if !device.isBooted {
                Button("启动") { Task { await appState.boot(device) } }
            }
            Button("关机") { Task { await appState.shutdown(device) } }
        }
    }
}

private struct PermissionStatusBar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PermissionRow(ok: appState.screenCapturePermission,
                          label: "屏幕录制",
                          hint: "镜像画面所需",
                          systemImage: "display")
            PermissionRow(ok: appState.accessibilityPermission,
                          label: "辅助功能",
                          hint: "点击注入所需",
                          systemImage: "cursorarrow.click")
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .onAppear {
            appState.refreshWindow()
        }
    }
}

private struct PermissionRow: View {
    let ok: Bool
    let label: String
    let hint: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(ok ? .green : .orange)
            Text(label)
                .font(.caption)
            Spacer()
            Text(ok ? "已授权" : "未授权")
                .font(.caption2)
                .foregroundStyle(ok ? .green : .orange)
        }
        .help(hint)
    }
}
