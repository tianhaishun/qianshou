import Foundation

/// WebDriverAgent HTTP 客户端（XCTest 触摸注入，不涉及 macOS 鼠标事件）
///
/// WDA 跑在模拟器内（testmanagerd 协议），与宿主共享网络栈，直接访问 localhost:8100。
/// 坐标使用设备逻辑 pt（iPhone 17 Pro = 402x874 @3x）。
@MainActor
final class WDAClient {

    static let shared = WDAClient()

    enum WDAError: LocalizedError {
        case notRunning
        case sessionFailed(String)
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notRunning: return "WDA 未运行（请先启动 scripts/start_wda.sh）"
            case .sessionFailed(let m): return "WDA 会话创建失败: \(m)"
            case .requestFailed(let m): return "WDA 请求失败: \(m)"
            }
        }
    }

    private let baseURL = URL(string: "http://localhost:8100")!
    private var sessionID: String?
    private(set) var screenSize: (width: Double, height: Double)?
    private(set) var isAlive = false

    // MARK: - 生命周期

    /// 检查 WDA 是否运行（GET /status）
    func checkAlive() async {
        var request = URLRequest(url: baseURL.appendingPathComponent("status"))
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            isAlive = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            isAlive = false
        }
    }

    /// 创建会话并读取设备屏幕尺寸
    func ensureSession() async throws {
        if sessionID != nil { return }
        guard isAlive else { throw WDAError.notRunning }

        var request = URLRequest(url: baseURL.appendingPathComponent("session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("""
        {"capabilities":{"alwaysMatch":{"bundleId":"com.apple.Preferences"}}}
        """.utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sid = json?["value"] as? [String: Any],
              let id = sid["sessionId"] as? String ?? (json?["sessionId"] as? String) else {
            throw WDAError.sessionFailed(String(data: data, encoding: .utf8) ?? "未知")
        }
        sessionID = id
        try await refreshScreenSize()
    }

    /// 读取设备逻辑分辨率（wda/screen → screenSize width/height）
    func refreshScreenSize() async throws {
        guard let sessionID else { return }
        let url = baseURL.appendingPathComponent("session/\(sessionID)/wda/screen")
        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = json["value"] as? [String: Any],
           let size = value["screenSize"] as? [String: Any],
           let w = size["width"] as? Double, let h = size["height"] as? Double {
            screenSize = (w, h)
        }
    }

    func closeSession() {
        sessionID = nil
        screenSize = nil
    }

    // MARK: - 触摸注入（设备逻辑 pt）

    /// 坐标点击
    func tap(x: Double, y: Double) async throws {
        try await post("wda/tap", body: ["x": x, "y": y])
    }

    /// 坐标拖拽（duration 0.5-60s）
    func drag(fromX: Double, fromY: Double, toX: Double, toY: Double, duration: Double) async throws {
        try await post("wda/dragfromtoforduration", body: [
            "fromX": fromX, "fromY": fromY,
            "toX": toX, "toY": toY,
            "duration": duration,
        ])
    }

    /// 输入文本
    func typeText(_ text: String) async throws {
        try await post("wda/keys", body: ["value": [text]])
    }

    /// 回主屏 / 锁屏
    func pressHome() async throws {
        try await post("wda/pressButton", body: ["name": "home"])
    }

    private func post(_ path: String, body: [String: Any]) async throws {
        guard let sessionID else { throw WDAError.sessionFailed("无会话") }
        var request = URLRequest(url: baseURL.appendingPathComponent("session/\(sessionID)/\(path)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw WDAError.requestFailed(String(data: data, encoding: .utf8) ?? "HTTP 错误")
        }
    }
}
