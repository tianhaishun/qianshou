import Foundation

/// 封装 `xcrun simctl`：设备列表、启动、关机、打开 Simulator 应用
enum SimulatorManager {

    struct SimctlError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 列出所有可用模拟器（含已关机），解析 `simctl list -j` 输出
    static func listDevices() async throws -> [SimulatorDevice] {
        let output = try await runSimctl(["list", "devices", "available", "-j"])
        let data = Data(output.utf8)
        struct ListPayload: Codable {
            let devices: [String: [SimulatorDevice]]
        }
        let payload = try JSONDecoder().decode(ListPayload.self, from: data)
        // 保留 runtime 键信息：simctl 的设备对象里没有 runtime 字段，用父键补上
        return payload.devices.flatMap { (runtimeKey, devices) in
            devices.map { device in
                SimulatorDevice(
                    name: device.name,
                    udid: device.udid,
                    state: device.state,
                    runtime: runtimeKey,
                    isAvailable: device.isAvailable
                )
            }
        }
        .sorted { $0.name < $1.name }
    }

    /// 启动模拟器（后台 boot，不弹窗口）
    static func boot(_ udid: String) async throws {
        _ = try await runSimctl(["boot", udid])
    }

    /// 关机
    static func shutdown(_ udid: String) async throws {
        _ = try await runSimctl(["shutdown", udid])
    }

    /// 打开 Simulator 应用并显示该设备（前台窗口必需）
    static func openSimulatorApp() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Simulator"]
        try? p.run()
    }

    /// 截取设备屏幕（用于调试/兜底）
    static func screenshot(_ udid: String, to url: URL) async throws {
        _ = try await runSimctl(["io", udid, "screenshot", url.path])
    }

    /// 安装 App（.app 或 .ipa），返回安装路径
    @discardableResult
    static func installApp(_ udid: String, at url: URL) async throws -> String {
        _ = try await runSimctl(["install", udid, url.path])
        return url.path
    }

    /// 启动 App（bundle id），返回进程 pid
    @discardableResult
    static func launchApp(_ udid: String, bundleID: String) async throws -> String {
        try await runSimctl(["launch", udid, bundleID])
    }

    /// 已安装 App 列表（User 类型）
    static func installedApps(_ udid: String) async throws -> [String] {
        let output = try await runSimctl(["listapps", udid, "--json"])
        struct Payload: Codable {
            let apps: [String: [String: String]]?
        }
        if let data = output.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return payload.apps?.keys.sorted() ?? []
        }
        return []
    }

    private static func runSimctl(_ args: [String]) async throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl"] + args
        // stderr 并入 stdout，避免分开读管道时 stderr 缓冲满导致死锁
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = outPipe
        try p.run()

        // 真正的异步等待（terminationHandler 回调，不阻塞调用线程）
        let status = await withCheckedContinuation { cont in
            p.terminationHandler = { proc in
                cont.resume(returning: proc.terminationStatus)
            }
        }
        // 进程已退出，管道数据完整可读
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()

        guard status == 0 else {
            let err = String(data: outData, encoding: .utf8) ?? ""
            throw SimctlError(message: "simctl \(args.joined(separator: " ")) 失败: \(err)")
        }
        return String(data: outData, encoding: .utf8) ?? ""
    }
}
