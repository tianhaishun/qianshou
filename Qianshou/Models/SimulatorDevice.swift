import CoreGraphics
import Foundation

/// 一个 iOS 模拟器设备（匹配 `xcrun simctl list devices -j` 输出）
struct SimulatorDevice: Identifiable, Codable, Equatable, Hashable {
    let name: String
    let udid: String
    let state: String
    /// simctl 设备对象里没有 runtime 字段，由 listDevices 用父键补充
    var runtime: String?
    let isAvailable: Bool

    var id: String { udid }

    var isBooted: Bool { state.lowercased() == "booted" }

    /// runtime 简写，如 "iOS 26.5"
    var runtimeShort: String {
        (runtime ?? "").replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
    }

    /// 设备逻辑分辨率（pt）。用于镜像自校准兜底，不在关键路径。
    var logicalSize: CGSize {
        // iPhone 17 Pro (iOS 26)：402x874 @3x
        if name.contains("iPad") {
            return name.contains("Pro 13") || name.contains("Pro 12") ? CGSize(width: 1032, height: 1376) : CGSize(width: 820, height: 1180)
        }
        return CGSize(width: 402, height: 874)
    }
}
