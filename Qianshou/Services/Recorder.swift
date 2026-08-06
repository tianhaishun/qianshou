import ApplicationServices
import CoreGraphics
import Foundation

/// 录制模拟器内容区内的真实点击操作（CGEventTap 全局监听）
///
/// 用户在模拟器窗口上的点击会被记录为相对坐标 + 时间偏移。
/// 需要辅助功能权限（与注入相同）。
@MainActor
final class Recorder: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var recordedCount = 0

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startTime: CFAbsoluteTime?
    private var points: [SequencePoint] = []
    /// 内容区屏幕 rect 提供者（录制前取最新）
    private var contentRectProvider: (() -> CGRect?)?

    private static var activeRecorder: Recorder?

    // MARK: - 录制

    func startRecording(contentRect: @escaping () -> CGRect?) {
        guard !isRecording, AXIsProcessTrusted() else { return }
        isRecording = true
        recordedCount = 0
        points = []
        startTime = CFAbsoluteTimeGetCurrent()
        contentRectProvider = contentRect
        Self.activeRecorder = self

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let recorder = Unmanaged<Recorder>.fromOpaque(userInfo).takeUnretainedValue()
                // tap source 挂主 run loop，回调必在主线程
                MainActor.assumeIsolated {
                    recorder.handleEvent(event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isRecording = false
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// 停止录制并返回序列；没录到任何点击返回 nil
    func stopRecording(name: String = "录制 \(DateFormatter.sequenceName.string(from: Date()))") -> ClickSequence? {
        guard isRecording else { return nil }
        stopTap()
        isRecording = false
        contentRectProvider = nil
        Self.activeRecorder = nil
        guard !points.isEmpty else { return nil }
        return ClickSequence(name: name, points: points, createdAt: Date())
    }

    func cancelRecording() {
        guard isRecording else { return }
        stopTap()
        isRecording = false
        points = []
        contentRectProvider = nil
        Self.activeRecorder = nil
    }

    private func stopTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// tap 回调（主线程）：记录内容区内的点击
    private func handleEvent(_ event: CGEvent) {
        guard isRecording, let startTime, let rect = contentRectProvider?() else { return }
        let p = event.location
        guard rect.contains(p) else { return }
        let rel = CGPoint(
            x: (p.x - rect.minX) / rect.width,
            y: (p.y - rect.minY) / rect.height
        )
        guard rel.x >= 0, rel.x <= 1, rel.y >= 0, rel.y <= 1 else { return }
        let offsetMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        points.append(SequencePoint(x: Double(rel.x), y: Double(rel.y), offsetMs: offsetMs))
        recordedCount = points.count
        DebugLog.log("[Recorder] recorded \(points.count): rel(\(rel.x), \(rel.y)) @\(offsetMs)ms")
    }
}

extension DateFormatter {
    static let sequenceName: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH-mm-ss"
        return f
    }()
}
