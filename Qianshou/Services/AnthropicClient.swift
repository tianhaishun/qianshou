import Foundation

/// Anthropic Messages API 客户端（raw HTTP，保持零第三方依赖）
///
/// 支持：多模态输入（截图 base64）、工具调用（manual loop）
@MainActor
final class AnthropicClient {

    struct Message: Codable {
        let role: String
        let content: [ContentBlock]
    }

    enum ContentBlock: Codable {
        case text(String)
        case thinking(String)
        case image(base64: String, mediaType: String = "image/png")
        case toolUse(id: String, name: String, input: [String: AnyCodable])
        case toolResult(toolUseID: String, content: String, isError: Bool = false)

        enum CodingKeys: String, CodingKey {
            case type, text, thinking, source, media_type, data, id, name, input, tool_use_id, content, is_error
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "text":
                self = .text(try c.decode(String.self, forKey: .text))
            case "thinking":
                self = .thinking(try c.decodeIfPresent(String.self, forKey: .thinking) ?? "")
            case "image":
                let source = try c.decode(ImageSource.self, forKey: .source)
                self = .image(base64: source.data, mediaType: source.mediaType)
            case "tool_use":
                let id = try c.decode(String.self, forKey: .id)
                let name = try c.decode(String.self, forKey: .name)
                let input = try c.decode([String: AnyCodable].self, forKey: .input)
                self = .toolUse(id: id, name: name, input: input)
            case "tool_result":
                let tid = try c.decode(String.self, forKey: .tool_use_id)
                let content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
                let isErr = try c.decodeIfPresent(Bool.self, forKey: .is_error) ?? false
                self = .toolResult(toolUseID: tid, content: content, isError: isErr)
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "未知 block: \(type)"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let t):
                try c.encode("text", forKey: .type)
                try c.encode(t, forKey: .text)
            case .thinking(let t):
                try c.encode("thinking", forKey: .type)
                try c.encode(t, forKey: .thinking)
            case .image(let b64, let mt):
                try c.encode("image", forKey: .type)
                try c.encode(ImageSource(mediaType: mt, data: b64), forKey: .source)
            case .toolUse(let id, let name, let input):
                try c.encode("tool_use", forKey: .type)
                try c.encode(id, forKey: .id)
                try c.encode(name, forKey: .name)
                try c.encode(input, forKey: .input)
            case .toolResult(let tid, let content, let isErr):
                try c.encode("tool_result", forKey: .type)
                try c.encode(tid, forKey: .tool_use_id)
                try c.encode(content, forKey: .content)
                try c.encode(isErr, forKey: .is_error)
            }
        }
    }

    private struct ImageSource: Codable {
        let type: String
        let mediaType: String
        let data: String

        init(mediaType: String, data: String) {
            self.type = "base64"
            self.mediaType = mediaType
            self.data = data
        }

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }

    /// 任意 JSON 值（工具参数编解码）
    struct AnyCodable: Codable {
        let value: Any

        init(_ value: Any) {
            // 解包已包装的 AnyCodable（嵌套字典 mapValues 会双重包装）
            if let wrapped = value as? AnyCodable {
                self.value = wrapped.value
            } else {
                self.value = value
            }
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let v = try? c.decode(Bool.self) { value = v }
            else if let v = try? c.decode(Double.self) { value = v }
            else if let v = try? c.decode(Int.self) { value = v }
            else if let v = try? c.decode(String.self) { value = v }
            else if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value) }
            else if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
            else { value = NSNull() }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch value {
            case let v as Bool: try c.encode(v)
            case let v as Double: try c.encode(v)
            case let v as Int: try c.encode(v)
            case let v as String: try c.encode(v)
            case let v as [Any]: try c.encode(v.map(AnyCodable.init))
            case let v as [String: Any]: try c.encode(v.mapValues(AnyCodable.init))
            case let v as [String: AnyCodable]: try c.encode(v)
            case let v as [String: String]: try c.encode(v)
            case let v as [String: Int]: try c.encode(v)
            case let v as [String: Double]: try c.encode(v)
            case let v as [String: Bool]: try c.encode(v)
            default: try c.encodeNil()
            }
        }
    }

    // MARK: - 响应

    struct ChatResponse: Decodable {
        let stopReason: String?
        let content: [ContentBlock]

        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case content
        }
    }

    struct ToolDef: Encodable {
        let name: String
        let description: String
        let inputSchema: [String: AnyCodable]

        enum CodingKeys: String, CodingKey {
            case name, description
            case inputSchema = "input_schema"
        }
    }

    enum ClientError: LocalizedError {
        case noAPIKey
        case http(Int, String)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "未配置 Anthropic API Key（⚙ 设置中填写）"
            case .http(let code, let msg): return "API 错误 \(code): \(msg)"
            case .decoding(let msg): return "响应解析失败: \(msg)"
            }
        }
    }

    var apiKey: String = ""
    /// 测试注入用：自定义 URLSessionConfiguration（URLProtocol stub）
    var sessionConfiguration: URLSessionConfiguration?
    /// OAuth Bearer Token（ANTHROPIC_AUTH_TOKEN / Claude Code / ant profile）
    var oauthToken: String = ""
    /// 自定义端点（ANTHROPIC_BASE_URL —— DeepSeek 等 Anthropic 兼容中转）
    var baseURL: String = ""
    var model: String = "claude-opus-4-8"

    private var endpoint: URL {
        if !baseURL.isEmpty, let url = URL(string: baseURL) {
            // 兼容两种配置：指向 /v1/messages 的完整端点 或 根地址
            if url.path.contains("messages") { return url }
            return url.appendingPathComponent("v1/messages")
        }
        return URL(string: "https://api.anthropic.com/v1/messages")!
    }

    /// 单轮请求（含工具定义、系统提示、图片）
    func chat(system: String, messages: [Message], tools: [ToolDef], maxTokens: Int = 4096) async throws -> ChatResponse {
        guard !apiKey.isEmpty || !oauthToken.isEmpty else { throw ClientError.noAPIKey }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": try JSONSerialization.jsonObject(with: JSONEncoder().encode(messages)) as? [Any] ?? [],
        ]
        if !tools.isEmpty {
            body["tools"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tools)) as? [Any] ?? []
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !oauthToken.isEmpty {
            // OAuth Bearer 认证（ant CLI / AUTH_TOKEN）
            request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        } else {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 每请求独立 session：避免 URLSession 连接复用导致的 TLS 失败；
        // 测试可注入带 URLProtocol stub 的配置
        let config: URLSessionConfiguration
        if let injected = sessionConfiguration {
            config = injected
        } else {
            config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 120
            config.timeoutIntervalForResource = 180
            config.httpMaximumConnectionsPerHost = 1
        }
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.decoding("无 HTTP 响应")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(http.statusCode, msg)
        }
        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw ClientError.decoding("\(error)")
        }
    }
}
