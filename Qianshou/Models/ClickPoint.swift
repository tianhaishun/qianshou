import Foundation

/// 一个连点点位：内容区相对坐标（0...1，相对模拟器内容区左上角）
/// 用相对坐标而非绝对坐标，模拟器窗口移动/缩放后依然准确
struct ClickPoint: Identifiable, Codable, Equatable {
    let id: UUID
    /// 相对内容区坐标（0...1）
    var x: Double
    var y: Double
    var label: String

    init(id: UUID = UUID(), x: Double, y: Double, label: String = "") {
        self.id = id
        self.x = x
        self.y = y
        self.label = label
    }
}
