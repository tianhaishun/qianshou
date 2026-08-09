import XCTest
@testable import Qianshou

/// AI 导出 flow 集成验证（真实凭据 + 真实模拟器）
///
/// 运行条件自动判定：本机有 AI 凭据 + WDA 存活才执行（CI 无此环境自动跳过）。
@MainActor
final class AIExportIntegrationTests: XCTestCase {

    private var agent: AIAgent?

    override func setUpWithError() throws {
        try super.setUpWithError()
        // CI 兜底：显式环境变量可直接禁用（xcodebuild 测试进程环境变量
        // 传递不稳定，主要靠下方的凭据 + WDA 就绪判定）
        if ProcessInfo.processInfo.environment["QIANSHOU_AI_IT"] == "0" {
            throw XCTSkip("集成测试已显式禁用")
        }
    }

    /// 真机闭环：AI 执行冒烟任务 → 导出 flow → 文件可被解析
    func testAIRunsAndExportsReplayableFlow() async throws {
        // 1. 运行环境就绪判定：凭据 + WDA 都活着才跑（CI 自动跳过）
        let cred = AICredentials.resolve()
        guard cred.isValid else {
            throw XCTSkip("无 AI 凭据（~/.claude/settings.json 或环境变量）")
        }
        await WDAClient.shared.checkAlive()
        guard WDAClient.shared.isAlive else {
            throw XCTSkip("WDA 未运行（模拟器未启动或注入服务未开启）")
        }

        // 2. 配置并运行一个短任务
        let ai = AIAgent()
        ai.configure(apiKey: cred.apiKey ?? "",
                     oauthToken: cred.oauthToken ?? "",
                     baseURL: cred.baseURL ?? "",
                     model: cred.model ?? "claude-opus-4-8")
        ai.run(goal: "打开设置 app，点击「通用」，然后结束")
        agent = ai

        // 3. 等待完成（最多 120s）
        let deadline = Date().addingTimeInterval(120)
        while ai.isRunning, Date() < deadline {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertFalse(ai.isRunning, "AI 应在 120s 内完成")
        XCTAssertTrue(ai.hasExportableFlow, "AI 应执行了至少一个动作")
        XCTAssertNotNil(ai.finalSummary, "AI 应给出总结")

        // 4. 导出 → 解析验证可回放
        guard let yaml = ai.exportFlow() else {
            return XCTFail("导出失败")
        }
        let document = try YAMLParser.parse(yaml)
        let commands = try FlowParser.parse(document).commands
        XCTAssertFalse(commands.isEmpty, "导出脚本应有命令")
        XCTAssertTrue(yaml.contains("tapOn"), "应有点击命令: \(yaml)")

        // 5. 落盘（供 CLI 回放验证）
        let out = URL(fileURLWithPath: "/tmp/qianshou-ai-export-test.yaml")
        try yaml.write(to: out, atomically: true, encoding: .utf8)
        print("📄 导出 flow 已写入: \(out.path)")
        print(yaml)
    }
}
