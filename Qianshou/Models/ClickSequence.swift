import Foundation

/// 序列中的一个动作：点击或拖动（内容区相对坐标 + 距序列开始的时间偏移）
struct SequencePoint: Codable, Equatable, Hashable {

    enum Kind: String, Codable, Hashable {
        case click
        case drag
    }

    var kind: Kind = .click
    var x: Double
    var y: Double
    /// 距序列开始的时间（毫秒）
    var offsetMs: Int
    /// 拖动终点（仅 kind == .drag）
    var endX: Double?
    var endY: Double?
    /// 拖动时长（仅 kind == .drag，毫秒）
    var durationMs: Int?

    // 自定义 Codable：新增字段带默认值，兼容旧版本保存的 JSON
    enum CodingKeys: String, CodingKey {
        case kind, x, y, offsetMs, endX, endY, durationMs
    }

    init(kind: Kind = .click, x: Double, y: Double, offsetMs: Int,
         endX: Double? = nil, endY: Double? = nil, durationMs: Int? = nil) {
        self.kind = kind
        self.x = x
        self.y = y
        self.offsetMs = offsetMs
        self.endX = endX
        self.endY = endY
        self.durationMs = durationMs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .click
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        offsetMs = try c.decodeIfPresent(Int.self, forKey: .offsetMs) ?? 0
        endX = try c.decodeIfPresent(Double.self, forKey: .endX)
        endY = try c.decodeIfPresent(Double.self, forKey: .endY)
        durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(offsetMs, forKey: .offsetMs)
        try c.encodeIfPresent(endX, forKey: .endX)
        try c.encodeIfPresent(endY, forKey: .endY)
        try c.encodeIfPresent(durationMs, forKey: .durationMs)
    }
}

/// 一段录制的动作序列（可保存/加载/回放）
struct ClickSequence: Codable, Equatable, Hashable {
    var name: String
    var points: [SequencePoint]
    var createdAt: Date

    var durationMs: Int {
        points.map(\.offsetMs).max() ?? 0
    }
}
