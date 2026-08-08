import SwiftUI

/// 主窗口 v2 —— 驾驶舱组合视图
///
/// 取代 v1 ContentView 的「镜像 + 底部玻璃条 + popover 弹层」结构:
///
///     ┌────────────── ToolbarView ──────────────┐
///     │  品牌 · 设备菜单                    ⌘K  │
///     ├───────────────────────────┬────────────┤
///     │                           │ 活动侧栏    │
///     │       MirrorCanvas        │ 连点/录制/AI│
///     │   (镜像永远居中可见)        │            │
///     │                           │            │
///     ├───────────────────────────┴────────────┤
///     │          StatusBarView 遥测条           │
///     └────────────────────────────────────────┘
///
/// 交互逻辑:
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
                    .padding(14)
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
