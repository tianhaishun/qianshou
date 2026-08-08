import SwiftUI

/// 主窗口 v4 —— 纸页排版:工具栏(页眉)/ 镜像(印版)/ 侧栏(目录)/ 遥测条(页脚)
///
///     ┌──────────────── ToolbarView ─────────────────┐
///     │  千手 · QIANSHOU   [设备 ▾]           ⌘K 命令 │
///     ├───────────────────────────────┬──────────────┤
///     │                               │ 01 · CLICKER │
///     │       MirrorCanvas            │ 02 · RECORDER│
///     │   (画布底部一条图注条)           │ 03 · PILOT   │
///     │                               │              │
///     ├───────────────────────────────┴──────────────┤
///     │    StatusBarView 遥测(页脚,零方框)             │
///     └──────────────────────────────────────────────┘
///
/// 交互逻辑(v2 已定,零改动):
/// - 活动切换由侧栏顶部三态承载(⌘1/⌘2/⌘3),镜像与状态条永不变形
/// - ⌘K 命令面板以覆盖层呈现,不脱离主窗口上下文
/// - 三种活动共享同一块镜像画布,点位/录制/AI 目标统一在画布上可视化
struct MainWindow: View {
    @EnvironmentObject private var appState: AppState
    @State private var activity: AppActivity = .clicker
    @State private var showCommandPalette = false

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(showCommandPalette: $showCommandPalette)

            HStack(spacing: 0) {
                MirrorCanvas()
                    .padding(DesignTokens.space16)
                ActivitySidebar(activity: $activity)
                    .frame(width: DesignTokens.sidebarWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView()
        }
        .background(DesignTokens.bgBase)
        .overlay {
            if showCommandPalette {
                CommandPaletteView(isPresented: $showCommandPalette, activity: $activity)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(DesignTokens.quick, value: showCommandPalette)
    }
}
