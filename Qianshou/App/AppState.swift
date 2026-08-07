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

    // MARK: - 全局热键

    private let hotKey = GlobalHotKey()
    @Published var hotKeyEnabled = false

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

    /// 刷新窗口定位并同步权限状态；按选中设备名优先匹配窗口
    func refreshWindow() {
        windowLocator.refresh(preferredTitle: selectedDevice?.name)
        screenCapturePermission = MirrorCapture.hasPermission()
        accessibilityPermission = AXIsProcessTrusted()
    }

    /// 镜像期间窗口位置/尺寸监控（每 1s），变化时重定位 + 用最近帧重校准
    private var windowMonitorTask: Task<Void, Never>?

    func startMirroring() async {
        DebugLog.log("[AppState] startMirroring begin")
        // 重复调用防护：先停旧捕获，避免 SCStream 泄漏
        if isMirroring {
            await stopMirroring()
        }
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
                    guard let self else { return }
                    self.mirrorFrame = image
                    // 用最新窗口 frame 校准内容区（frame 由窗口监控任务保持新鲜；
                    // scale 自动推导：帧像素 / 窗口 pt，兼容 Retina 2x）
                    if let window = self.windowLocator.window {
                        self.windowLocator.calibrate(
                            contentPixelSize: CGSize(width: image.width, height: image.height),
                            frameSize: window.frame.size
                        )
                    }
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
            startWindowMonitor()
        } catch {
            DebugLog.log("[AppState] capture error: \(error)")
            errorMessage = "镜像启动失败: \(error.localizedDescription)"
        }
    }

    /// 镜像期间定时刷新窗口定位（移动/缩放后注入坐标保持准确）
    private func startWindowMonitor() {
        windowMonitorTask?.cancel()
        windowMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isMirroring else { return }
                let oldFrame = self.windowLocator.window?.frame
                self.refreshWindow()
                // frame 变化 → 用最近帧重新校准（scale 自动推导）
                if let newWindow = self.windowLocator.window,
                   let frame = self.mirrorFrame,
                   oldFrame != newWindow.frame {
                    self.windowLocator.calibrate(
                        contentPixelSize: CGSize(width: frame.width, height: frame.height),
                        frameSize: newWindow.frame.size
                    )
                }
            }
        }
    }

    func stopMirroring() async {
        windowMonitorTask?.cancel()
        windowMonitorTask = nil
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
        // 与回放/录制互斥（代码层防护，不只依赖 UI 禁用）
        guard !player.isPlaying else {
            errorMessage = "请先停止回放再开始连点"
            return
        }
        guard !recorder.isRecording else {
            errorMessage = "请先停止录制再开始连点"
            return
        }
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
        // 连点运行中禁止录制（注入的点击会被录进去，污染序列）
        guard !clickEngine.isRunning else {
            errorMessage = "请先停止连点再开始录制"
            return
        }
        guard !player.isPlaying else {
            errorMessage = "请先停止回放再开始录制"
            return
        }
        recorder.startRecording { [weak self] in
            self?.windowLocator.window?.contentRect
        }
    }

    func stopRecording() {
        if let seq = recorder.stopRecording() {
            lastRecordedSequence = seq
            do {
                try SequenceStore.save(seq)
            } catch {
                errorMessage = "保存序列失败: \(error.localizedDescription)"
            }
            loadSequences()
        }
    }

    func cancelRecording() {
        recorder.cancelRecording()
    }

    func playSequence(_ sequence: ClickSequence) {
        // 与连点/录制互斥（代码层防护）
        guard !clickEngine.isRunning else {
            errorMessage = "请先停止连点再回放"
            return
        }
        guard !recorder.isRecording else {
            errorMessage = "请先停止录制再回放"
            return
        }
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

    // MARK: - 全局热键

    /// 安装/卸载 F8 热键（任意 App 下按 F8 开始/停止连点）
    func setHotKey(enabled: Bool) {
        hotKeyEnabled = enabled
        if enabled {
            let ok = hotKey.install { [weak self] in
                guard let self else { return }
                if self.clickEngine.isRunning {
                    self.stopClicking()
                } else if !self.clickPoints.isEmpty {
                    self.startClicking()
                }
            }
            if !ok {
                // 无辅助功能权限时全局监听不生效，提示并回滚开关
                hotKeyEnabled = false
                errorMessage = "F8 热键需要辅助功能权限，请先授权"
            }
        } else {
            hotKey.uninstall()
        }
    }

    /// 让 Simulator 窗口到前台（点击注入的前置条件）
    func activateSimulator() {
        SimulatorManager.openSimulatorApp()
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iphonesimulator")
            .first?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
