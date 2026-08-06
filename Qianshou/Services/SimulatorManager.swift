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

    private static func runSimctl(_ args: [String]) async throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl"] + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else {
            let err = String(data: errData, encoding: .utf8) ?? ""
            throw SimctlError(message: "simctl \(args.joined(separator: " ")) 失败: \(err)")
        }
        return String(data: outData, encoding: .utf8) ?? ""
    }
}
