import SwiftUI

/// 沉浸式布局：顶部工具栏 + 镜像主导区 + 底部浮动操作条
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView()
            MirrorView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.top, 10)
            BottomBarView()
        }
        .overlay(alignment: .top) {
            if let toast = appState.toast {
                ToastView(message: toast)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(DesignTokens.bgBase)
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
