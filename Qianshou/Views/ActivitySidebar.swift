import SwiftUI

/// 驾驶舱活动(侧栏三态)
enum AppActivity: String, CaseIterable, Identifiable {
    case clicker
    case recorder
    case pilot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clicker: return "连点"
        case .recorder: return "录制回放"
        case .pilot: return "AI 驾驶"
        }
    }

    /// 印刷小标(caps 索引注)
    var note: String {
        switch self {
        case .clicker: return "CLICKER"
        case .recorder: return "RECORDER"
        case .pilot: return "PILOT"
        }
    }

    var symbol: String {
        switch self {
        case .clicker: return "cursorarrow.click.2"
        case .recorder: return "record.circle"
        case .pilot: return "sparkles"
        }
    }

    /// 快捷键字符(Character 可直接转 KeyEquivalent;⌘ 显示用插值)
    var shortcut: Character {
        switch self {
        case .clicker: return "1"
        case .recorder: return "2"
        case .pilot: return "3"
        }
    }
}

/// 活动侧栏 v4 —— 目录页(TOC)
///
/// 三个活动平铺为三个面板,镜像永远可见;交互逻辑(v2 已定,零改动):
/// - 切换活动 = 切换面板(⌘1/⌘2/⌘3)
/// - 顶部改为目录式索引:mono 序号 + serif 标题 + 快捷键提示,
///   选中 = accentDim 平底 + accentText 序号(accent 每屏第一处)
/// - 每个面板自带主操作按钮,不与其他活动抢焦点
struct ActivitySidebar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var activity: AppActivity

    var body: some View {
        VStack(spacing: 0) {
            activityTOC
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Rectangle()
                .fill(DesignTokens.border)
                .frame(height: 1)
            Group {
                switch activity {
                case .clicker: ClickerPanel()
                case .recorder: RecorderPanel()
                case .pilot: AIPilotPanel()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignTokens.bgCard)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignTokens.border)
                .frame(width: 1)
        }
    }

    // MARK: - 目录(取代 v3 分段控件:serif 标题 + mono 序号)

    private var activityTOC: some View {
        VStack(spacing: 2) {
            ForEach(Array(AppActivity.allCases.enumerated()), id: \.element.id) { index, item in
                TOCRow(index: index, item: item, isActive: activity == item) {
                    withAnimation(DesignTokens.quick) {
                        activity = item
                    }
                }
            }
        }
    }
}

/// 目录行:01 + serif 标题 + ⌘N 提示;选中 = accentDim 平底
private struct TOCRow: View {
    let index: Int
    let item: AppActivity
    let isActive: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Text(String(format: "%02d", index + 1))
                    .font(DesignTokens.mono(9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(isActive ? DesignTokens.accentText : DesignTokens.textTertiary)
                    .frame(width: 16, alignment: .leading)
                Text(item.title)
                    .font(DesignTokens.display(16, weight: .semibold))
                    .foregroundStyle(isActive ? DesignTokens.ink : DesignTokens.textSecondary)
                    .lineSpacing(3)
                Spacer(minLength: 0)
                Controls.KbdHint(text: "⌘" + String(item.shortcut), highlighted: isActive)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.radiusControl))
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                    .fill(isActive
                          ? DesignTokens.accentDim
                          : (hovering ? DesignTokens.bgSunken.opacity(0.5) : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(item.shortcut), modifiers: .command)
        .onHover { hovering = $0 }
        .accessibilityLabel("切换到\(item.title)")
        .help("切换到\(item.title)(⌘" + String(item.shortcut) + ")")
    }
}
