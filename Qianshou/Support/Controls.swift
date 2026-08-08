import SwiftUI

/// v4 共享控件:按钮样式、状态灯、分区标题、输入字段
///
/// 对比度约定(全部实测,见 DesignTokens 头注):
/// - 实心主按钮 = accent 填充 + 墨字(4.9:1),悬停只移背景亮度,前景永不降对比
/// - 实心停止 = err/record 填充 + 纸字(7.7:1 / 4.9:1)
/// - 描边危险 = 语义色字 + 语义色浅底(字 7.2:1)
/// - disabled 是唯一允许降低对比的状态(0.4 opacity)
enum Controls {

    // MARK: - 按钮样式

    /// 主 CTA:accent 填充 + 墨字(Claude 原味,每屏至多一个)
    struct PrimaryButtonStyle: ButtonStyle {
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(13, weight: .semibold))
                .foregroundStyle(DesignTokens.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(DesignTokens.accent)
                        .brightness(hovering ? 0.05 : 0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .brightness(configuration.isPressed ? -0.03 : 0)
                .onHover { hovering = $0 }
        }
    }

    /// 确认操作(回答发送):ok 实心填充 + 纸字(5.4:1)
    struct SuccessButtonStyle: ButtonStyle {
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(12, weight: .semibold))
                .foregroundStyle(DesignTokens.paper)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(DesignTokens.ok)
                        .brightness(hovering ? 0.05 : 0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 运行中主操作:err/record 实心填充 + 纸字
    struct StopButtonStyle: ButtonStyle {
        var color: Color = DesignTokens.err
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(13, weight: .semibold))
                .foregroundStyle(DesignTokens.paper)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(color)
                        .brightness(hovering ? 0.05 : 0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 次级操作:细线边框 + 墨字;悬停抬升底,文字不变
    struct SecondaryButtonStyle: ButtonStyle {
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(12, weight: .medium))
                .foregroundStyle(DesignTokens.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(hovering ? DesignTokens.bgCardRaised : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .stroke(hovering ? DesignTokens.borderStrong : DesignTokens.border, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 危险/停止(次级):语义色字 + 语义色浅底
    struct DangerButtonStyle: ButtonStyle {
        var color: Color = DesignTokens.err
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(color.opacity(hovering ? 0.16 : 0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .stroke(color.opacity(hovering ? 0.75 : 0.45), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 文字按钮(列表行内):悬停只加底,永不把前景变灰
    struct PlainButtonStyle: ButtonStyle {
        var tint: Color = DesignTokens.textSecondary
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(11))
                .foregroundStyle(tint)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(hovering ? DesignTokens.bgSunken.opacity(0.7) : Color.clear)
                )
                .opacity(configuration.isPressed ? 0.75 : 1)
                .onHover { hovering = $0 }
        }
    }

    // MARK: - 状态灯

    /// 状态点:运行 = 语义色 + 呼吸辉光,熄灭 = off
    struct StatusDot: View {
        let color: Color
        var pulsing = false

        var body: some View {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: pulsing ? color.opacity(0.65) : .clear, radius: 3)
                .animation(
                    pulsing
                        ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
        }
    }

    // MARK: - 分区标题(印刷小标)

    /// 分区标题:中文 sans 11 墨字 + caps 索引(mono 9,0.12em tracking)+ 计数 + 延伸细线
    ///
    /// 形如:
    ///   点位 · POINTS  3 ────────────────────────
    /// 计数徽标用纸灰底墨字,不占用 accent(accent 每屏 ≤2)。
    struct EditorialSection: View {
        let title: String
        var note: String? = nil
        var count: Int? = nil

        var body: some View {
            HStack(spacing: 8) {
                Text(title)
                    .font(DesignTokens.ui(11, weight: .semibold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineSpacing(2)
                if let note {
                    Text(note)
                        .font(DesignTokens.caps(8.5))
                        .tracking(DesignTokens.capsTracking(for: 8.5))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                if let count {
                    Text("\(count)")
                        .font(DesignTokens.mono(9, weight: .semibold))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignTokens.bgSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(DesignTokens.border, lineWidth: 1)
                        )
                }
                Spacer(minLength: 0)
                Rectangle()
                    .fill(DesignTokens.border)
                    .frame(height: 1)
                    .frame(maxWidth: 56)
            }
        }
    }

    // MARK: - 快捷键提示

    /// 快捷键/键位框:mono 9 + 凹槽底 + 印刷线(如 ⌘K / F8 / 空格)
    struct KbdHint: View {
        let text: String
        var highlighted = false

        var body: some View {
            Text(text)
                .font(DesignTokens.mono(9, weight: .semibold))
                .foregroundStyle(highlighted ? DesignTokens.accentText : DesignTokens.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(DesignTokens.bgSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .stroke(highlighted ? DesignTokens.accentBorder : DesignTokens.border, lineWidth: 1)
                )
        }
    }

    // MARK: - 输入字段

    /// 编辑字段:凹槽底 + 印刷线 + 2px 圆角;聚焦时保留系统 focus ring
    struct EditorialField: View {
        let placeholder: String
        @Binding var text: String
        var mono = false
        var onSubmit: (() -> Void)? = nil

        var body: some View {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(mono ? DesignTokens.mono(12) : DesignTokens.ui(12))
                .foregroundStyle(DesignTokens.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .fill(DesignTokens.bgSunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusControl)
                        .stroke(DesignTokens.border, lineWidth: 1)
                )
                .onSubmit {
                    onSubmit?()
                }
        }
    }

    // MARK: - 数字滑块

    /// 参数滑块:label sans 11 + mono 读数 + 滑轨(accent 只此一处)
    struct MetricSlider: View {
        let label: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        let step: Double
        let display: String

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(label)
                        .font(DesignTokens.ui(11))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineSpacing(2)
                    Spacer()
                    Text(display)
                        .font(DesignTokens.mono(11, weight: .medium))
                        .foregroundStyle(DesignTokens.ink)
                        .contentTransition(.numericText())
                        .animation(DesignTokens.quick, value: display)
                }
                Slider(value: $value, in: range, step: step)
                    .tint(DesignTokens.ink)
                    .controlSize(.small)
            }
        }
    }
}
