import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            VStack(spacing: 0) {
                MirrorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                ControlPanelView()
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .task {
            DebugLog.log("[ContentView] task begin")
            appState.startPollingDevices()
        }
        .onChange(of: appState.screenCapturePermission) { _, granted in
            // 屏幕录制权限从拒绝变为授权后自动恢复镜像
            if granted && !appState.isMirroring {
                Task { await appState.startMirroring() }
            }
        }
        .alert("千手", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}
