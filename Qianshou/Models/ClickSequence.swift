import Foundation

/// 序列中的一个点击：内容区相对坐标 + 距序列开始的时间偏移
struct SequencePoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    /// 距序列开始的时间（毫秒）
    var offsetMs: Int
}

/// 一段录制的点击序列（可保存/加载/回放）
struct ClickSequence: Codable, Equatable, Hashable {
    var name: String
    var points: [SequencePoint]
    var createdAt: Date

    var durationMs: Int {
        points.map(\.offsetMs).max() ?? 0
    }
}
