import SwiftUI

/// v2 共享控件:按钮样式、状态灯、分区标题
/// 对比度约定:实心按钮 = 亮色填充 + 深色字(≥4.5:1);hover 只提亮背景,永不降前景对比。
enum Controls {

    // MARK: - 按钮样式

    /// 主 CTA:accent 填充 + 深字(每屏至多一个)
    struct PrimaryButtonStyle: ButtonStyle {
        var color: Color = DesignTokens.accent
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(13, weight: .semibold))
                .foregroundStyle(Color(hex: 0x06121C))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color)
                        .brightness(hovering ? 0.08 : 0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 次级操作:细线边框 + 抬升底
    struct SecondaryButtonStyle: ButtonStyle {
        @State private var hovering = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(12, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovering ? DesignTokens.bgCardRaised : DesignTokens.bgCardRaised.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(hovering ? DesignTokens.borderStrong : DesignTokens.border, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 危险/停止:描边 + 语义色字(避免实心红底白字对比不足)
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
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(hovering ? 0.16 : 0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(color.opacity(hovering ? 0.75 : 0.45), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { hovering = $0 }
        }
    }

    /// 文字按钮(列表行内)
    struct PlainButtonStyle: ButtonStyle {
        var tint: Color = DesignTokens.textSecondary

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DesignTokens.ui(11))
                .foregroundStyle(tint)
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }

    // MARK: - 状态灯

    /// 状态点:启动/运行 = 语义色 + 呼吸辉光,熄灭 = off
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

    /// 细线读数 chip:等宽数据 + 可选状态灯(遥测条 / 工具栏复用)
    struct TelemetryChip: View {
        let label: String
        let value: String
        var dotColor: Color?

        var body: some View {
            HStack(spacing: 6) {
                if let dotColor {
                    StatusDot(color: dotColor, pulsing: true)
                }
                Text(label)
                    .font(DesignTokens.ui(10))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text(value)
                    .font(DesignTokens.mono(11, weight: .medium))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(DesignTokens.bgSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(DesignTokens.border, lineWidth: 1)
            )
        }
    }

    // MARK: - 分区标题

    /// 侧栏分区标题:小号语义标题 + 计数徽标 + 右侧细线延伸
    struct SectionHeader: View {
        let title: String
        var count: Int? = nil
        var accent = false

        var body: some View {
            HStack(spacing: 6) {
                Text(title)
                    .font(DesignTokens.ui(11, weight: .semibold))
                    .foregroundStyle(accent ? DesignTokens.accent : DesignTokens.textSecondary)
                if let count {
                    Text("\(count)")
                        .font(DesignTokens.mono(9, weight: .bold))
                        .foregroundStyle(accent ? Color(hex: 0x06121C) : DesignTokens.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(accent ? DesignTokens.accent : DesignTokens.bgCardRaised)
                        )
                }
                Spacer(minLength: 0)
                Rectangle()
                    .fill(DesignTokens.border)
                    .frame(height: 1)
                    .frame(maxWidth: 40)
            }
        }
    }

    // MARK: - 数字滑块

    /// 参数滑块:label + mono 读数 + 滑轨
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
                    Spacer()
                    Text(display)
                        .font(DesignTokens.mono(11, weight: .medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .contentTransition(.numericText())
                        .animation(DesignTokens.quick, value: display)
                }
                Slider(value: $value, in: range, step: step)
                    .tint(DesignTokens.accent)
                    .controlSize(.small)
            }
        }
    }
}
