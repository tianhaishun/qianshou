import SwiftUI

/// 千手 v2 入口 —— 替换 v1 QianShouApp.swift
///
/// 仅入口变化:ContentView → MainWindow。
/// AppState 与全部模型/服务层沿用 v1,接口已由 v2 视图层验证匹配。
@main
struct QianShouApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
        }
        .defaultSize(width: 1180, height: 800)
        .windowResizability(.contentMinSize)
    }
}
