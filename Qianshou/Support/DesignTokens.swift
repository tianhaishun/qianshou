import SwiftUI

/// 千手设计令牌 v2 —— 驾驶舱操作台语言
///
/// 深蓝黑底 + 千手青单 accent + 细线边框 + mono 数据读数。
/// 相比 v1:砍掉蓝青渐变滥用与发光阴影,状态反馈靠「线 + 灯 + 读数」,
/// 每屏 accent 至多出现 2 处(通常:1 个选中态 + 1 个主 CTA)。
enum DesignTokens {

    // MARK: 品牌(千手青 —— 全应用唯一 accent)

    static let accent = Color(hex: 0x22D3EE)
    /// 选中/激活底
    static let accentDim = Color(hex: 0x22D3EE, opacity: 0.14)
    /// 高亮描边
    static let accentBorder = Color(hex: 0x22D3EE, opacity: 0.42)

    // MARK: 背景层(深蓝黑,禁用纯黑)

    static let bgBase = Color(hex: 0x0B1220)        // 窗口底
    static let bgCard = Color(hex: 0x0E1626)        // 侧栏/卡片
    static let bgCardRaised = Color(hex: 0x131D31)  // 输入底/悬浮
    static let bgSunken = Color(hex: 0x090F1B)      // 镜像画布底

    // MARK: 边框(半透明白 = 结构,不是噪音)

    static let border = Color(hex: 0x8FA3C8, opacity: 0.14)
    static let borderStrong = Color(hex: 0x8FA3C8, opacity: 0.26)

    // MARK: 语义色

    static let ok = Color(hex: 0x34D399)
    static let warn = Color(hex: 0xFBBF24)
    static let err = Color(hex: 0xFF453A)
    static let record = Color(hex: 0xFF375F)
    static let off = Color(hex: 0x475569)

    // MARK: 文字

    static let textPrimary = Color(hex: 0xE8EEF9)
    static let textSecondary = Color(hex: 0x9FB0CC)
    static let textTertiary = Color(hex: 0x64748B)

    // MARK: 度量(8pt 网格)

    static let cornerRadius: CGFloat = 8
    static let spacing: CGFloat = 8
    static let sidebarWidth: CGFloat = 336
    static let toolbarHeight: CGFloat = 44
    static let statusBarHeight: CGFloat = 30
    static let markerDiameter: CGFloat = 22

    // MARK: 字体

    /// 数据读数:坐标 / 时长 / 轮次 / 状态码 —— 一律等宽
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// UI 与正文:系统默认字体(Apple 生态原生)
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: 动效

    static let quick = Animation.easeOut(duration: 0.18)
    static let soft = Animation.easeOut(duration: 0.3)

    // MARK: - v1 兼容别名(新代码禁止使用,仅保证旧文件可编译)

    @available(*, deprecated, message: "v2 弃用渐变,请用扁平 accent")
    static let brandDeep = Color(hex: 0x2563EB)
    @available(*, deprecated, message: "v2 弃用渐变,请用扁平 accent")
    static let brandMid = Color(hex: 0x06B6D4)
    @available(*, deprecated, message: "v2 弃用,请用 accent")
    static let brandBright = Color(hex: 0x22D3EE)
    @available(*, deprecated, message: "v2 弃用渐变,请用扁平 accent")
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x2563EB), Color(hex: 0x06B6D4), Color(hex: 0x22D3EE)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    @available(*, deprecated, message: "v2 弃用,请用 accentBorder")
    static let borderHover = Color(hex: 0x22D3EE, opacity: 0.26)
    @available(*, deprecated, message: "v2 弃用,请用 accentDim")
    static let brandTint = Color(hex: 0x22D3EE, opacity: 0.12)
    @available(*, deprecated, message: "v2 弃用发光,请用扁平填充")
    static let brandGlow = Color(hex: 0x22D3EE, opacity: 0.33)
    @available(*, deprecated, message: "v2 弃用,请用 border/borderStrong")
    static let borderCard = Color(hex: 0x1F2D4C, opacity: 0.6)
    @available(*, deprecated, message: "v2 弃用,请用 ui()")
    static let pointBounce = Animation.spring(duration: 0.4, bounce: 0.35)
    @available(*, deprecated, message: "v2 弃用,请用 soft")
    static let cardHover = Animation.easeOut(duration: 0.3)
}

extension Color {
    /// 从 hex 整数值构造颜色(0xRRGGBB),可选透明度
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
