import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HSplitView {
            SidebarView()
            VStack(spacing: 0) {
                MirrorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ControlPanelView()
                    .padding(.top, 10)
            }
            .padding(12)
            .background(DesignTokens.bgBase)
        }
        .frame(minWidth: 980, minHeight: 640)
        .preferredColorScheme(.dark)
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
