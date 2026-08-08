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

    var symbol: String {
        switch self {
        case .clicker: return "cursorarrow.click.2"
        case .recorder: return "record.circle"
        case .pilot: return "sparkles"
        }
    }

    var shortcut: String {
        switch self {
        case .clicker: return "1"
        case .recorder: return "2"
        case .pilot: return "3"
        }
    }
}

/// 活动侧栏 v2 —— 取代 v1 的 popover 弹层与底部操作条
///
/// 三种活动平铺为三个面板,镜像永远可见;交互逻辑:
/// - 切换活动 = 切换面板(⌘1/⌘2/⌘3)
/// - 每个面板自带主操作按钮,不与其他活动抢焦点
struct ActivitySidebar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var activity: AppActivity

    var body: some View {
        VStack(spacing: 0) {
            activityPicker
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)
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

    // MARK: - 活动切换(自定义分段,细线语言)

    private var activityPicker: some View {
        HStack(spacing: 4) {
            ForEach(AppActivity.allCases) { item in
                ActivityButton(item: item, isActive: activity == item) {
                    withAnimation(DesignTokens.quick) {
                        activity = item
                    }
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.bgSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignTokens.border, lineWidth: 1)
        )
    }
}


/// 活动切换按钮(拆分子视图,避免 SwiftUI 泛型推断超时)
private struct ActivityButton: View {
    let item: AppActivity
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: item.symbol)
                    .font(.system(size: 11))
                Text(item.title)
                    .font(DesignTokens.ui(11, weight: .semibold))
                Text("⌘\(item.shortcut)")
                    .font(DesignTokens.mono(9))
                    .foregroundStyle(isActive ? DesignTokens.accent.opacity(0.75) : DesignTokens.textTertiary)
            }
            .foregroundStyle(isActive ? DesignTokens.accent : DesignTokens.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? DesignTokens.accentDim : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(item.shortcut)), modifiers: .command)
        .accessibilityLabel("切换到\(item.title)")
        .help("切换到\(item.title)(⌘\(item.shortcut))")
    }
}
