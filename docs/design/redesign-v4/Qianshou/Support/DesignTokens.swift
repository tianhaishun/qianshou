import SwiftUI

/// 千手设计令牌 v4 —— 纸页排版系统
///
/// 参照系:Anthropic / Claude 的排版传统。v3 只模仿了色板(暖纸 + 陶土橙),
/// 这一版以「字体 · 对比 · 排版」为核心重建:
///
/// 1. 字体角色(三套,谁都不越位)
///    - serif(New York):标题与情绪 —— 品牌、面板标题、空态引导
///    - sans(SF Pro):功能 —— 标签、输入、按钮、正文
///    - mono(SF Mono):数据与索引 —— 坐标、时序、遥测、caps 小标
///    CJK 标题行高 ≥1.3(lineSpacing 4),负 tracking 只给拉丁字母。
///
/// 2. 对比(每对都算过,数字见下)
///    - 墨 #23211E 在 纸 #FAF9F5 ≈ 14.7:1
///    - 次级 #57534C 在 面板 #F2EFE8 ≈ 6.6:1
///    - 三级 #66605A 在 凹槽 #EBE7DE ≈ 5.6:1
///    - 主按钮:accent #D97757 填充 + 墨字 ≈ 4.9:1(v3 的 accentStrong 深底
///      配墨字只有 3.5:1,反而不达标 —— 已退役)
///    - 停止按钮:err #B5452F 填充 + 纸字 ≈ 7.7:1 / record 填充 + 纸字 ≈ 4.9:1
///    - accentText #A64B2A 在 面板 ≈ 5.3:1
///    - warn #8A641F 在 纸 ≈ 5.0:1(v3 的 #A67B2D 只有 3.6:1,已加深)
///
/// 3. 排版(4pt 网格)
///    - 半径:画布 8 · 面板 4 · 控件 2;胶囊与大圆角退役
///    - 画布底部一条 mono 图注条(figure caption),取代三个浮动 chip
///    - 侧栏 = 目录:serif 标题 + mono 索引号;遥测条 = 页脚:零方框
///    - 间距:16(区)/ 12(组)/ 8(行)/ 4(微)
enum DesignTokens {

    // MARK: 品牌(陶土橙 —— 全应用唯一 accent,每屏至多 2 处)

    /// 品牌橙:主按钮填充 / 数据高亮(Claude 原味 #D97757,配墨字 4.9:1)
    static let accent = Color(hex: 0xD97757)
    /// 文字用橙:选中态 / 链接(纸页上 ≈5.3:1)
    static let accentText = Color(hex: 0xA64B2A)
    /// 选中/激活底(平底,不描边)
    static let accentDim = Color(hex: 0xD97757, opacity: 0.13)
    /// 高亮描边(悬停/运行中的点位)
    static let accentBorder = Color(hex: 0xD97757, opacity: 0.40)

    // MARK: 纸页背景(禁用纯黑纯白)

    static let bgBase = Color(hex: 0xFAF9F5)        // 窗口底:纸白
    static let bgCard = Color(hex: 0xF2EFE8)        // 侧栏/工具栏:比纸深一档
    static let bgCardRaised = Color(hex: 0xFDFCF9)  // 输入底/悬浮/按钮纸字
    static let bgSunken = Color(hex: 0xEBE7DE)      // 画布底/字段底:凹槽

    // MARK: 印刷线(1px 暖灰实线,不是发光)

    static let border = Color(hex: 0xE0DBD0)
    static let borderStrong = Color(hex: 0xC6C0B2)

    // MARK: 语义色(只表达状态,不参与装饰)

    static let ok = Color(hex: 0x54724A)      // 就绪:暖橄榄(纸页上 5.0:1)
    static let warn = Color(hex: 0x8A641F)    // 提问/提示:深琥珀(纸页上 5.0:1)
    static let err = Color(hex: 0xB5452F)     // 停止/错误:砖红(纸页上 7.2:1)
    static let record = Color(hex: 0xC7432F)  // 录制:陶土深红
    static let off = Color(hex: 0xA39E93)     // 熄灭:纸灰

    // MARK: 文字(暖墨色阶,禁用纯黑)

    /// 墨:一级文字 / 实心按钮上的文字
    static let ink = Color(hex: 0x23211E)
    static let textPrimary = Color(hex: 0x23211E)
    static let textSecondary = Color(hex: 0x57534C)
    static let textTertiary = Color(hex: 0x66605A)  // 仅限说明/图注级文字

    /// 实心按钮上的纸色文字(#FDFCF9)
    static let paper = Color(hex: 0xFDFCF9)

    // MARK: 度量(4pt 网格)

    static let radiusCanvas: CGFloat = 8     // 镜像画布 / 命令面板
    static let radiusPanel: CGFloat = 4      // 面板内卡片 / 截图
    static let radiusControl: CGFloat = 2    // 按钮 / 字段 / 小控件
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let sidebarWidth: CGFloat = 336
    static let toolbarHeight: CGFloat = 46
    static let statusBarHeight: CGFloat = 28
    static let captionBarHeight: CGFloat = 32  // 画布图注条
    static let markerDiameter: CGFloat = 22

    // MARK: 字体角色(三套分工:serif 情绪 · sans 功能 · mono 数据)

    /// Display:serif(New York,气质最接近 Tiempos)。只用于标题/情绪位:
    /// 品牌(17)、面板标题(20)、画布空态(22)。CJK 请配 lineSpacing(4) 保证行高 ≥1.3。
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// UI:sans(SF Pro)。功能位:标签 11 / 正文 12 / 按钮 13。
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Data:mono(SF Mono)。数据位:读数 11 / 图注 10 / 快捷键 9。
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// 印刷小标:mono semibold + 0.12em tracking(仅拉丁 caps,如 QIANSHOU / POINTS)
    static func caps(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
            .monospacedDigit()
    }

    /// 印刷小标的标准 tracking(0.12em)
    static func capsTracking(for size: CGFloat) -> CGFloat { size * 0.12 }

    // MARK: 动效

    static let quick = Animation.easeOut(duration: 0.18)
    static let soft = Animation.easeOut(duration: 0.3)

    // MARK: - v3 兼容别名(旧代码可编译;新代码禁止使用)

    @available(*, deprecated, message: "v4 主按钮直接用 accent(配墨字 4.9:1);此深档只在选中底上使用")
    static let accentStrong = Color(hex: 0xB05536)
    @available(*, deprecated, message: "v4 用 bgCardRaised 做按钮纸字")
    static let accentGlow = Color(hex: 0xD97757, opacity: 0.33)
    @available(*, deprecated, message: "v4 用 border/borderStrong")
    static let borderCard = Color(hex: 0xE0DBD0, opacity: 0.9)
    @available(*, deprecated, message: "v4 用 caps()")
    static let qianshouCaps = Font.system(size: 8, weight: .medium, design: .monospaced)
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
