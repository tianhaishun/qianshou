import AppKit
import Foundation
import SwiftUI

/// 全局状态：设备列表、选中设备、镜像、权限
@MainActor
final class AppState: ObservableObject {

    @Published var devices: [SimulatorDevice] = []
    @Published var selectedDevice: SimulatorDevice?
    @Published var isRefreshingDevices = false
    @Published var errorMessage: String?
    @Published var mirrorFrame: CGImage?

    // 权限状态（页面展示用）
    @Published var screenCapturePermission = MirrorCapture.hasPermission()
    @Published var accessibilityPermission = AXIsProcessTrusted()

    private var refreshTask: Task<Void, Never>?
    let windowLocator = WindowLocator()
    private var mirrorCapture: MirrorCapture?

    // MARK: - 连点状态

    @Published var clickPoints: [ClickPoint] = []
    @Published var clickIntervalMs: Double = 500
    @Published var clickLoopIntervalMs: Double = 1000
    @Published var clickLoops: Int = 1
    let clickEngine = ClickEngine()

    // MARK: - 录制/回放

    let recorder = Recorder()
    let player = Player()
    @Published var savedSequences: [ClickSequence] = []
    @Published var lastRecordedSequence: ClickSequence?

    var simulatorWindow: WindowLocator.SimulatorWindow? { windowLocator.window }

    // MARK: - 设备列表

    func startPollingDevices() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDevices()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stopPollingDevices() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshDevices() async {
        isRefreshingDevices = true
        defer { isRefreshingDevices = false }
        do {
            let list = try await SimulatorManager.listDevices()
            devices = list
            // 选中设备跟随：优先保持原选择，否则选第一个 Booted，再否则第一个
            if let selectedDevice,
               let stillThere = list.first(where: { $0.udid == selectedDevice.udid }) {
                self.selectedDevice = stillThere
            } else if let booted = list.first(where: { $0.isBooted }) {
                selectedDevice = booted
            } else {
                selectedDevice = list.first
            }
        } catch {
            errorMessage = "获取模拟器列表失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 模拟器启停

    func boot(_ device: SimulatorDevice) async {
        do {
            try await SimulatorManager.boot(device.udid)
            SimulatorManager.openSimulatorApp()
            await refreshDevices()
        } catch {
            errorMessage = "启动模拟器失败: \(error.localizedDescription)"
        }
    }

    func shutdown(_ device: SimulatorDevice) async {
        do {
            try await SimulatorManager.shutdown(device.udid)
            await refreshDevices()
        } catch {
            errorMessage = "关闭模拟器失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 镜像

    /// 刷新窗口定位并同步权限状态；窗口变化时由调用方决定重连
    func refreshWindow() {
        windowLocator.refresh()
        screenCapturePermission = MirrorCapture.hasPermission()
        accessibilityPermission = AXIsProcessTrusted()
    }

    func startMirroring() async {
        DebugLog.log("[AppState] startMirroring begin")
        refreshWindow()
        DebugLog.log("[AppState] window=\(String(describing: windowLocator.window?.title)) permission=\(screenCapturePermission)")
        guard let window = windowLocator.window else {
            errorMessage = "找不到模拟器窗口，请先启动模拟器"
            return
        }
        guard screenCapturePermission else {
            DebugLog.log("[AppState] no screen capture permission, requesting...")
            MirrorCapture.requestPermission()
            errorMessage = "需要屏幕录制权限：请在系统设置中允许「千手」后重试"
            return
        }
        mirrorCapture = MirrorCapture(
            onFrame: { [weak self] image in
                DispatchQueue.main.async {
                    self?.mirrorFrame = image
                    // 首帧校准内容区（窗口捕获含标题栏，捕获分辨率 1x = pt）
                    self?.windowLocator.calibrate(
                        contentPixelSize: CGSize(width: image.width, height: image.height),
                        scaleFactor: 1.0
                    )
                }
            },
            onStop: { [weak self] in
                DispatchQueue.main.async {
                    self?.mirrorFrame = nil
                    self?.errorMessage = "镜像已断开（模拟器窗口可能已关闭）"
                }
            }
        )
        do {
            DebugLog.log("[AppState] starting capture for windowID=\(window.windowID)")
            try await mirrorCapture?.start(windowID: window.windowID)
            DebugLog.log("[AppState] capture started: \(mirrorCapture?.isCapturing ?? false)")
        } catch {
            DebugLog.log("[AppState] capture error: \(error)")
            errorMessage = "镜像启动失败: \(error.localizedDescription)"
        }
    }

    func stopMirroring() async {
        await mirrorCapture?.stop()
        mirrorFrame = nil
    }

    var isMirroring: Bool { mirrorCapture?.isCapturing ?? false }

    // MARK: - 连点控制

    /// 添加点位（内容区相对坐标 0...1）
    func addClickPoint(x: Double, y: Double) {
        let label = "点 \(clickPoints.count + 1)"
        clickPoints.append(ClickPoint(x: x, y: y, label: label))
    }

    func removeClickPoint(at offsets: IndexSet) {
        clickPoints.remove(atOffsets: offsets)
    }

    func clearClickPoints() {
        clickPoints.removeAll()
    }

    func startClicking() {
        clickEngine.start(
            points: clickPoints,
            intervalMs: Int(clickIntervalMs),
            loopIntervalMs: Int(clickLoopIntervalMs),
            loops: clickLoops,
            contentRect: { [weak self] in self?.windowLocator.window?.contentRect },
            onActivateSimulator: { [weak self] in self?.activateSimulator() }
        )
    }

    func stopClicking() {
        clickEngine.stop()
    }

    // MARK: - 录制/回放控制

    func startRecording() {
        recorder.startRecording { [weak self] in
            self?.windowLocator.window?.contentRect
        }
    }

    func stopRecording() {
        if let seq = recorder.stopRecording() {
            lastRecordedSequence = seq
            try? SequenceStore.save(seq)
            loadSequences()
        }
    }

    func cancelRecording() {
        recorder.cancelRecording()
    }

    func playSequence(_ sequence: ClickSequence) {
        player.play(
            sequence: sequence,
            contentRect: { [weak self] in self?.windowLocator.window?.contentRect },
            onActivateSimulator: { [weak self] in self?.activateSimulator() }
        )
    }

    func loadSequences() {
        savedSequences = SequenceStore.loadAll()
    }

    func deleteSequence(_ sequence: ClickSequence) {
        SequenceStore.delete(sequence)
        loadSequences()
    }

    /// 让 Simulator 窗口到前台（点击注入的前置条件）
    func activateSimulator() {
        SimulatorManager.openSimulatorApp()
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iphonesimulator")
            .first?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
