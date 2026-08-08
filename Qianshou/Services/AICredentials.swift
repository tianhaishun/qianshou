import Foundation

/// AI 凭据解析 —— 复用本地已有配置，不强制用户重新配置
///
/// 探测顺序（与 Anthropic SDK 一致）：
/// 1. 环境变量 ANTHROPIC_API_KEY（x-api-key 认证）
/// 2. 环境变量 ANTHROPIC_AUTH_TOKEN（OAuth Bearer 认证）
/// 3. ant CLI 配置文件 ~/.config/anthropic/（登录过的 profile）
enum AICredentials {

    struct Resolved {
        /// x-api-key 认证（ANTHROPIC_API_KEY）
        let apiKey: String?
        /// OAuth Bearer 认证（ANTHROPIC_AUTH_TOKEN / Claude Code / ant profile）
        let oauthToken: String?
        /// 自定义端点（ANTHROPIC_BASE_URL —— 如 DeepSeek 中转）
        let baseURL: String?
        /// 模型（ANTHROPIC_MODEL —— 如 deepseek-v4-flash[1M]）
        let model: String?
        /// 来源描述（展示用）
        let source: String

        var isValid: Bool { apiKey != nil || oauthToken != nil }
    }

    static func resolve() -> Resolved {
        let env = ProcessInfo.processInfo.environment

        // 1) 环境变量（ANTHROPIC_API_KEY / AUTH_TOKEN / BASE_URL / MODEL）
        if let cred = fromEnv(env) {
            return cred
        }

        // 2) Claude Code 配置（~/.claude/settings.json 的 env —— 用户最常在这里配置）
        if let cred = fromClaudeCodeSettings() {
            return cred
        }

        // 3) ant CLI 配置（~/.config/anthropic/）
        if let profile = resolveAntProfile() {
            return profile
        }

        return Resolved(apiKey: nil, oauthToken: nil, baseURL: nil, model: nil, source: "未配置")
    }

    /// 从环境变量解析（含 base URL 与模型）
    private static func fromEnv(_ env: [String: String]) -> Resolved? {
        let key = env["ANTHROPIC_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }
        let token = env["ANTHROPIC_AUTH_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
        guard key != nil || token != nil else { return nil }
        return Resolved(
            apiKey: key,
            oauthToken: token,
            baseURL: env["ANTHROPIC_BASE_URL"].flatMap { $0.isEmpty ? nil : $0 },
            model: env["ANTHROPIC_MODEL"].flatMap { $0.isEmpty ? nil : $0 },
            source: key != nil ? "环境变量 ANTHROPIC_API_KEY" : "环境变量 ANTHROPIC_AUTH_TOKEN"
        )
    }

    /// 从 Claude Code 配置（~/.claude/settings.json 的 env）解析 —— 用户最常见的配置位置
    private static func fromClaudeCodeSettings() -> Resolved? {
        let settingsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = settings["env"] as? [String: String] else {
            return nil
        }
        let key = env["ANTHROPIC_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }
        let token = env["ANTHROPIC_AUTH_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
        guard key != nil || token != nil else { return nil }
        return Resolved(
            apiKey: key,
            oauthToken: token,
            baseURL: env["ANTHROPIC_BASE_URL"].flatMap { $0.isEmpty ? nil : $0 },
            model: env["ANTHROPIC_MODEL"].flatMap { $0.isEmpty ? nil : $0 },
            source: "Claude Code 配置 (~/.claude/settings.json)"
        )
    }

    /// 读取 ant CLI 登录过的 profile（settings.json → 激活 profile → credentials）
    private static func resolveAntProfile() -> Resolved? {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/anthropic")

        // settings.json 的 activeProfile
        let settingsURL = configDir.appendingPathComponent("settings.json")
        var profileName = "default"
        if let data = try? Data(contentsOf: settingsURL),
           let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = settings["activeProfile"] as? String {
            profileName = active
        }

        // credentials/<profile>.json 的 access_token
        let credURL = configDir.appendingPathComponent("credentials/\(profileName).json")
        guard let data = try? Data(contentsOf: credURL),
              let cred = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = cred["access_token"] as? String, !token.isEmpty else {
            return nil
        }
        return Resolved(apiKey: nil, oauthToken: token, baseURL: nil, model: nil, source: "ant profile（\(profileName)）")
    }
}
