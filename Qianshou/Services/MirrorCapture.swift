import AppKit
import CoreMedia
import Foundation
import ScreenCaptureKit

/// 用 ScreenCaptureKit 实时捕获 Simulator 窗口，逐帧回调 CGImage
///
/// - 捕获整个窗口（含标题栏），内容区校准交给 WindowLocator
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
    private var filter: SCContentFilter?
    private let onFrame: @Sendable (CGImage) -> Void
    private let onStop: (() -> Void)?

    init(onFrame: @escaping @Sendable (CGImage) -> Void, onStop: (() -> Void)? = nil) {
        self.onFrame = onFrame
        self.onStop = onStop
    }

    static func hasPermission() -> Bool {
        if #available(macOS 15.0, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return CGPreflightScreenCaptureAccess()
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
        stream = SCStream(filter: filter!, configuration: config, delegate: self)
        try stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await stream!.startCapture()
        isRunning = true
    }

    func stop() async {
        guard let stream else { return }
        isRunning = false
        try? await stream.stopCapture()
        self.stream = nil
    }

    var isCapturing: Bool { isRunning }
}

extension MirrorCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // 保持引用稳定后转 CGImage 回调（由 UI 线程绘制）
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let image = pixelBuffer.toCGImage()
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        if let image {
            onFrame(image)
        }
    }
}

extension MirrorCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isRunning = false
        onStop?()
    }
}

private extension CVPixelBuffer {
    /// 将 CVPixelBuffer 转为 CGImage（BIOSRGB 渲染，支持 IOSurface 加速路径）
    func toCGImage() -> CGImage? {
        let ci = CIImage(cvPixelBuffer: self)
        let context = CIContext()
        return context.createCGImage(ci, from: ci.extent)
    }
}
