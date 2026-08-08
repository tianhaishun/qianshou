import AppKit
import SwiftUI

/// ⌘K 命令面板 v4 —— 键盘驱动的全局操作入口
///
/// 取代 v1 分散在菜单与工具栏中的零散操作,让高频操作全部键盘直达:
/// 「输入即过滤、↑↓ 选择、回车执行、Esc 关闭」。
///
/// 排版改动:选中行改为 2px 平底(radius 10 → 8),搜索行保持无框,
/// 快捷键用 mono 9 读数;交互逻辑(v2 已定,零改动)。
///
/// 命令覆盖:切换活动(⌘1/2/3) / 启停连点 / 启停录制 / 连接镜像 /
/// 打开序列目录 / 安装 App / F8 热键开关 / 刷新设备列表。
struct CommandPaletteView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @Binding var activity: AppActivity

    @State private var query = ""
    @State private var selection = 0

    private var filtered: [PaletteCommand] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = allCommands
        guard !q.isEmpty else { return base }
        return base.filter { $0.title.contains(q) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                searchField
                Rectangle()
                    .fill(DesignTokens.border)
                    .frame(height: 1)
                commandList
                Rectangle()
                    .fill(DesignTokens.border)
                    .frame(height: 1)
                footer
            }
            .frame(width: 500)
            .background(DesignTokens.bgCardRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusCanvas))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusCanvas)
                    .stroke(DesignTokens.borderStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.24), radius: 26, y: 12)
            .frame(maxHeight: 430)
            .onExitCommand { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { selection = 0 }
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.textTertiary)
            TextField("搜索命令…", text: $query)
                .textFieldStyle(.plain)
                .font(DesignTokens.ui(13))
                .foregroundStyle(DesignTokens.ink)
                .onKeyPress(.escape) {
                    dismiss()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if !filtered.isEmpty {
                        selection = max(selection - 1, 0)
                    }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if !filtered.isEmpty {
                        selection = min(selection + 1, filtered.count - 1)
                    }
                    return .handled
                }
                .onSubmit {
                    if filtered.indices.contains(selection) {
                        run(filtered[selection])
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - 命令列表

    private var commandList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if filtered.isEmpty {
                        Text("无匹配命令")
                            .font(DesignTokens.ui(12))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .padding(.vertical, 26)
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, cmd in
                            row(for: cmd, index: index)
                                .id(cmd.id)
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: selection) { _, newValue in
                guard filtered.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(filtered[newValue].id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func row(for cmd: PaletteCommand, index: Int) -> some View {
        let selected = index == selection
        let enabled = cmd.isEnabled()
        return Button {
            run(cmd)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: cmd.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        selected ? DesignTokens.accentText
                            : (enabled ? DesignTokens.textSecondary : DesignTokens.textTertiary)
                    )
                    .frame(width: 18)
                Text(cmd.title)
                    .font(DesignTokens.ui(12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(
                        selected ? DesignTokens.accentText
                            : (enabled ? DesignTokens.ink : DesignTokens.textTertiary)
                    )
                    .lineLimit(1)
                Spacer()
                Text(cmd.hint)
                    .font(DesignTokens.mono(9, weight: .medium))
                    .foregroundStyle(
                        selected ? DesignTokens.accentText.opacity(0.75) : DesignTokens.textTertiary
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl).fill(DesignTokens.accentDim)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.radiusControl))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering in
            if hovering && enabled { selection = index }
        }
    }

    // MARK: - 底部提示

    private var footer: some View {
        HStack(spacing: 12) {
            Text("↑↓ 选择")
            Text("↵ 执行")
            Text("esc 关闭")
            Spacer()
            Text("\(filtered.count) 条命令")
        }
        .font(DesignTokens.mono(9))
        .foregroundStyle(DesignTokens.textTertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - 命令集

    private var allCommands: [PaletteCommand] {
        var list: [PaletteCommand] = []

        // 活动切换(与侧栏 ⌘1/2/3 一致)
        for item in AppActivity.allCases {
            list.append(PaletteCommand(
                id: "activity-\(item.rawValue)",
                title: "切换到\(item.title)",
                symbol: item.symbol,
                hint: "⌘\(item.shortcut)",
                isEnabled: { true },
                action: { activity = item }
            ))
        }

        // 运行控制(标题随状态变化)
        list.append(PaletteCommand(
            id: "click-toggle",
            title: appState.clickEngine.isRunning ? "停止连点" : "开始连点",
            symbol: appState.clickEngine.isRunning ? "stop.fill" : "play.fill",
            hint: appState.clickEngine.isRunning ? "RUN" : "SPACE",
            isEnabled: {
                appState.clickEngine.isRunning
                    || (!appState.clickPoints.isEmpty
                        && !appState.player.isPlaying
                        && !appState.recorder.isRecording)
            },
            action: {
                if appState.clickEngine.isRunning {
                    appState.stopClicking()
                } else {
                    appState.startClicking()
                }
            }
        ))
        list.append(PaletteCommand(
            id: "record-toggle",
            title: appState.recorder.isRecording ? "停止并保存录制" : "开始录制",
            symbol: appState.recorder.isRecording ? "stop.fill" : "record.circle",
            hint: appState.recorder.isRecording ? "REC" : "●",
            isEnabled: {
                appState.recorder.isRecording
                    || (!appState.clickEngine.isRunning && !appState.player.isPlaying)
            },
            action: {
                if appState.recorder.isRecording {
                    appState.stopRecording()
                } else {
                    appState.startRecording()
                }
            }
        ))

        // 设备与文件
        list.append(PaletteCommand(
            id: "mirror-connect",
            title: "连接镜像",
            symbol: "arrow.triangle.2.circlepath",
            hint: appState.isMirroring ? "ON" : "OFF",
            isEnabled: { !appState.isMirroring },
            action: { Task { await appState.startMirroring() } }
        ))
        list.append(PaletteCommand(
            id: "refresh-devices",
            title: "刷新设备列表",
            symbol: "arrow.clockwise",
            hint: "DEV",
            isEnabled: { true },
            action: { Task { await appState.refreshDevices() } }
        ))
        list.append(PaletteCommand(
            id: "install-app",
            title: "安装 App…",
            symbol: "square.and.arrow.down",
            hint: "APP",
            isEnabled: { true },
            action: { installApp() }
        ))
        list.append(PaletteCommand(
            id: "sequences-folder",
            title: "打开序列文件夹",
            symbol: "folder",
            hint: "DIR",
            isEnabled: { true },
            action: { openSequencesFolder() }
        ))

        // F8 热键
        list.append(PaletteCommand(
            id: "f8-toggle",
            title: appState.hotKeyEnabled ? "停用 F8 全局热键" : "启用 F8 全局热键",
            symbol: "keyboard",
            hint: appState.hotKeyEnabled ? "ON" : "OFF",
            isEnabled: { true },
            action: { appState.setHotKey(enabled: !appState.hotKeyEnabled) }
        ))

        return list
    }

    // MARK: - 动作

    private func run(_ command: PaletteCommand) {
        guard command.isEnabled() else { return }
        command.action()
        dismiss()
    }

    private func dismiss() {
        withAnimation(DesignTokens.quick) {
            isPresented = false
        }
    }

    private func installApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "app") ?? .application,
            .init(filenameExtension: "ipa") ?? .archive,
        ]
        panel.allowsMultipleSelection = false
        panel.message = "选择 .app 或 .ipa 安装到模拟器"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await appState.installAndLaunchApp(at: url) }
        }
    }

    private func openSequencesFolder() {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("QianShou/sequences", isDirectory: true) else { return }
        NSWorkspace.shared.open(dir)
    }
}

// MARK: - 命令模型

/// 面板命令:标题随状态动态生成,启用条件与副作用均为闭包(每次求值取最新状态)
private struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let hint: String
    let isEnabled: () -> Bool
    let action: () -> Void
}
