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
        /// OAuth Bearer 认证（ANTHROPIC_AUTH_TOKEN / ant profile）
        let oauthToken: String?
        /// 来源描述（展示用）
        let source: String

        var isValid: Bool { apiKey != nil || oauthToken != nil }
    }

    static func resolve() -> Resolved {
        let env = ProcessInfo.processInfo.environment

        // 1) API Key（优先，且不会被 OAuth 遮蔽 —— 若两者都设置，SDK 行为是发送两者会被拒绝，这里取 key）
        if let key = env["ANTHROPIC_API_KEY"], !key.isEmpty {
            return Resolved(apiKey: key, oauthToken: nil, source: "环境变量 ANTHROPIC_API_KEY")
        }

        // 2) OAuth Bearer Token
        if let token = env["ANTHROPIC_AUTH_TOKEN"], !token.isEmpty {
            return Resolved(apiKey: nil, oauthToken: token, source: "环境变量 ANTHROPIC_AUTH_TOKEN")
        }

        // 3) ant CLI 配置（~/.config/anthropic/）
        if let profile = resolveAntProfile() {
            return profile
        }

        return Resolved(apiKey: nil, oauthToken: nil, source: "未配置")
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
        return Resolved(apiKey: nil, oauthToken: token, source: "ant profile（\(profileName)）")
    }
}
