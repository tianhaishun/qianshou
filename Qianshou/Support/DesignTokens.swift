import SwiftUI

/// 千手设计令牌：品牌色板、背景层、语义色、度量（8pt 网格）
/// 全部 SwiftUI 系统能力，零第三方依赖
enum DesignTokens {

    // MARK: 品牌色（青蓝渐变）

    static let brandDeep = Color(hex: 0x2563EB)
    static let brandMid = Color(hex: 0x06B6D4)
    static let brandBright = Color(hex: 0x22D3EE)
    /// 主渐变：135° 蓝→青→亮青
    static let brandGradient = LinearGradient(
        colors: [brandDeep, brandMid, brandBright],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// 边框光晕/发光色
    static let brandGlow = Color(hex: 0x22D3EE, opacity: 0.33)
    /// 选中态底色
    static let brandTint = Color(hex: 0x22D3EE, opacity: 0.12)

    // MARK: 背景层（深色）

    static let bgBase = Color(hex: 0x0B1220)
    static let bgCard = Color(hex: 0x121B30, opacity: 0.92)
    static let bgCardRaised = Color(hex: 0x1A2742)
    static let bgSunken = Color(hex: 0x0A111F)
    static let borderCard = Color(hex: 0x1F2D4C, opacity: 0.6)
    static let borderHover = Color(hex: 0x22D3EE, opacity: 0.26)

    // MARK: 语义色

    static let ok = Color(hex: 0x34D399)
    static let warn = Color(hex: 0xFBBF24)
    static let off = Color(hex: 0x475569)
    static let err = Color(hex: 0xFF453A)
    static let record = Color(hex: 0xFF375F)

    // MARK: 文字

    static let textPrimary = Color(hex: 0xE8EEF9)
    static let textSecondary = Color(hex: 0x9FB0CC)
    static let textTertiary = Color(hex: 0x64748B)

    // MARK: 度量

    static let cornerRadius: CGFloat = 10
    static let spacing: CGFloat = 8
    static let sidebarWidth: CGFloat = 240
    /// 点位徽标直径
    static let markerDiameter: CGFloat = 24

    // MARK: 动效

    static let pointBounce = Animation.spring(duration: 0.4, bounce: 0.35)
    static let cardHover = Animation.easeOut(duration: 0.3)
    static let quick = Animation.easeOut(duration: 0.2)
}

extension Color {
    /// 从 hex 整数值构造颜色（0xRRGGBB），可选透明度
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
