import XCTest
@testable import Qianshou

/// AnthropicClient 网络层测试：请求编码、响应解析（URLProtocol stub，不发真实请求）
@MainActor
final class AnthropicClientTests: XCTestCase {

    /// 带 URLProtocol stub 的 session 配置
    private var stubConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testChatRequestEncoding() async throws {
        // 捕获请求
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { request in
            let data = MockURLProtocol.bodyData(from: request)
            capturedBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            // 返回简单文本响应
            let body = #"{"content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn"}"#
            return (response, body.data(using: .utf8)!)
        }

        let client = AnthropicClient()
        client.apiKey = "test-key"
        client.sessionConfiguration = stubConfiguration
        let response = try await client.chat(
            system: "测试系统提示",
            messages: [AnthropicClient.Message(role: "user", content: [.text("你好")])],
            tools: [AnthropicClient.ToolDef(
                name: "tap",
                description: "点击",
                inputSchema: ["type": AnthropicClient.AnyCodable("object")]
            )]
        )

        // 响应解析
        XCTAssertEqual(response.stopReason, "end_turn")
        if case .text(let t) = response.content[0] {
            XCTAssertEqual(t, "hi")
        } else {
            XCTFail("应为 text block")
        }

        // 请求体结构
        let body = try XCTUnwrap(capturedBody)
        XCTAssertEqual(body["model"] as? String, "claude-opus-4-8")
        XCTAssertEqual(body["max_tokens"] as? Int, 4096)
        XCTAssertEqual(body["system"] as? String, "测试系统提示")

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")

        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["name"] as? String, "tap")
        let schema = try XCTUnwrap(tools[0]["input_schema"] as? [String: Any])
        XCTAssertEqual(schema["type"] as? String, "object")
    }

    func testVisionImageBlockEncoding() async throws {
        MockURLProtocol.requestHandler = { request in
            let data = MockURLProtocol.bodyData(from: request)
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let messages = body?["messages"] as? [[String: Any]]
            let content = messages?.first?["content"] as? [[String: Any]]
            let image = content?.first { $0["type"] as? String == "image" }
            XCTAssertEqual((image?["source"] as? [String: Any])?["type"] as? String, "base64")
            XCTAssertEqual((image?["source"] as? [String: Any])?["media_type"] as? String, "image/png")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, #"{"content":[],"stop_reason":"end_turn"}"#.data(using: .utf8)!)
        }

        let client = AnthropicClient()
        client.apiKey = "k"
        client.sessionConfiguration = stubConfiguration
        let msg = AnthropicClient.Message(role: "user", content: [
            .image(base64: "aGVsbG8="),
            .text("描述"),
        ])
        _ = try await client.chat(system: "", messages: [msg], tools: [])
    }

    func testToolUseResponseParsing() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            let body = """
            {"content":[
                {"type":"text","text":"我来操作"},
                {"type":"tool_use","id":"toolu_01","name":"tap","input":{"x":200,"y":400}}
            ],"stop_reason":"tool_use"}
            """
            return (response, body.data(using: .utf8)!)
        }

        let client = AnthropicClient()
        client.apiKey = "k"
        client.sessionConfiguration = stubConfiguration
        let response = try await client.chat(
            system: "",
            messages: [AnthropicClient.Message(role: "user", content: [.text("go")])],
            tools: []
        )

        XCTAssertEqual(response.stopReason, "tool_use")
        let toolUses = response.content.compactMap { block -> AnthropicClient.ContentBlock? in
            if case .toolUse = block { return block }
            return nil
        }
        XCTAssertEqual(toolUses.count, 1)
        if case .toolUse(let id, let name, let input) = toolUses[0] {
            XCTAssertEqual(id, "toolu_01")
            XCTAssertEqual(name, "tap")
            XCTAssertEqual(input["x"]?.value as? Double, 200)
            XCTAssertEqual(input["y"]?.value as? Double, 400)
        }
    }

    func testMissingAPIKeyError() async {
        let client = AnthropicClient()
        client.apiKey = ""
        do {
            _ = try await client.chat(system: "", messages: [], tools: [])
            XCTFail("应抛错")
        } catch let error as AnthropicClient.ClientError {
            if case .noAPIKey = error {
                // 正确
            } else {
                XCTFail("错误类型不对: \(error)")
            }
        } catch {
            XCTFail("错误类型不对: \(error)")
        }
    }
}

/// URLProtocol stub：拦截 URLSession 请求，返回预设响应
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// 读取请求体（URLSession 可能把 httpBody 转成 httpBodyStream）
    static func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: bufSize)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}
