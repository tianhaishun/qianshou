import AppKit
import CoreMedia
import Foundation
import ScreenCaptureKit

/// 用 ScreenCaptureKit 实时捕获 Simulator 窗口，逐帧回调 CGImage
///
/// - 捕获整个窗口（含标题栏），内容区校准交给 WindowLocator
/// - 像素转换在后台队列执行（sampleHandlerQueue），只把 CGImage hop 回调用方
/// - 必须持有 stream 实例；stop() 后释放
final class MirrorCapture: NSObject, @unchecked Sendable {

    enum CaptureError: LocalizedError {
        case noPermission
        case windowNotFound

        var errorDescription: String? {
            switch self {
            case .noPermission: return "没有屏幕录制权限"
            case .windowNotFound: return "找不到模拟器窗口"
            }
        }
    }

    private var stream: SCStream?
    private var isRunning = false
    /// 主动停止标志：避免 stop() 后 didStopWithError 回调触发「镜像已断开」误报
    private var intentionalStop = false
    private var filter: SCContentFilter?
    private let onFrame: @Sendable (CGImage) -> Void
    private let onStop: (() -> Void)?
    /// CIContext 建一次复用（GPU 上下文创建昂贵）
    private let ciContext = CIContext()
    /// 像素转换后台队列
    private let convertQueue = DispatchQueue(label: "com.qianshou.mirror-convert")

    init(onFrame: @escaping @Sendable (CGImage) -> Void, onStop: (() -> Void)? = nil) {
        self.onFrame = onFrame
        self.onStop = onStop
    }

    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 请求屏幕录制权限（首次会弹系统授权窗）
    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// 开始捕获指定窗口
    func start(windowID: CGWindowID) async throws {
        guard MirrorCapture.hasPermission() else { throw CaptureError.noPermission }
        await stop()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false
        config.capturesAudio = false

        filter = SCContentFilter(desktopIndependentWindow: window)
        let newStream = SCStream(filter: filter!, configuration: config, delegate: self)
        stream = newStream
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: convertQueue)
            try await newStream.startCapture()
            isRunning = true
            intentionalStop = false
        } catch {
            // 失败路径清理，避免残留未启动的 stream
            try? await newStream.stopCapture()
            stream = nil
            filter = nil
            throw error
        }
    }

    func stop() async {
        guard let stream else { return }
        intentionalStop = true
        isRunning = false
        try? await stream.stopCapture()
        self.stream = nil
        filter = nil
    }

    var isCapturing: Bool { isRunning }
}

extension MirrorCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // 后台队列上做像素转换（CI 渲染），避免占用 SCStream 内部队列
        convertQueue.async { [weak self] in
            guard let self, let image = pixelBuffer.toCGImage(context: self.ciContext) else { return }
            self.onFrame(image)
        }
    }
}

extension MirrorCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // SCStream 回调可能不在主线程，isRunning 统一回主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            // 主动停止（stop()）不触发「断开」提示
            guard !self.intentionalStop else { return }
            self.onStop?()
        }
    }
}

private extension CVPixelBuffer {
    /// 将 CVPixelBuffer 转为 CGImage（复用传入的 CIContext）
    func toCGImage(context: CIContext) -> CGImage? {
        let ci = CIImage(cvPixelBuffer: self)
        return context.createCGImage(ci, from: ci.extent)
    }
}
