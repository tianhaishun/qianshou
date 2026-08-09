import Foundation

/// 千手 CLI — 脚本化回放序列
///
/// 用法:
///   qianshou run <sequence.json> [--loops N] [--udid UDID]
///   qianshou list                    # 列出已保存序列
@main
struct QianshouCLI {

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        do {
            switch args.first {
            case "run":
                try await run(args)
            case "list":
                try listSequences()
            case "help", "--help", "-h", nil:
                printUsage()
            default:
                print("未知命令: \(args.first ?? "")")
                printUsage()
            }
        } catch {
            print("✗ \(error.localizedDescription)")
            exit(1)
        }
    }

    // MARK: - 命令实现

    static func run(_ args: [String]) async throws {
        guard args.count >= 2 else {
            print("用法: qianshou run <sequence.json 或 flow.yaml> [--loops N]")
            exit(1)
        }
        let path = args[1]
        var loops = 1
        if let idx = args.firstIndex(of: "--loops"), idx + 1 < args.count {
            loops = Int(args[idx + 1]) ?? 1
        }

        // 按扩展名分流：.yaml/.yml → flow 脚本；.json → 点击序列
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "yaml", "yml":
            try await runFlow(path: path)
        case "json":
            try await runSequence(path: path, loops: loops)
        default:
            print("不支持的文件类型 .\(ext)（支持 .yaml flow 脚本 或 .json 点击序列）")
            exit(1)
        }
    }

    /// 执行 YAML flow 脚本
    private static func runFlow(path: String) async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let yamlText = String(data: data, encoding: .utf8) else {
            print("✗ 无法读取文件（非 UTF-8）: \(path)")
            exit(1)
        }
        let document = try YAMLParser.parse(yamlText)
        let (appId, commands) = try FlowParser.parse(document)

        print("千手 CLI — 执行 flow「\(path.split(separator: "/").last ?? "")」")
        print("  appId: \(appId ?? "（沿用当前会话）") · \(commands.count) 条命令")
        print("  连接 WDA ...")

        var completed = 0
        try await FlowRunner.run(commands: commands, appId: appId) { index, total, desc in
            completed += 1
            print("  ✓ [\(index + 1)/\(total)] \(desc)")
        }
        print("✅ flow 执行完成（\(completed) 条命令）")
    }

    /// 回放点击序列（JSON）
    private static func runSequence(path: String, loops: Int) async throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(ClickSequence.self, from: data)

        print("千手 CLI — 回放「\(sequence.name)」")
        print("  \(sequence.points.count) 个动作 × \(loops) 轮 · 时长 \(String(format: "%.1f", Double(sequence.durationMs) / 1000))s")
        print("  连接 WDA ...")
        print("  session: \(await WDAClient.shared.debugSessionID ?? "?"))")

        var completed = 0
        try await SequenceRunner.run(sequence: ClickSequence(
            name: sequence.name,
            points: sequence.points,
            createdAt: sequence.createdAt,
            loops: loops
        )) { index, total in
            completed += 1
            print("  ✓ 动作 \(index + 1)/\(total)")
        }
        print("✅ 回放完成（\(completed) 个动作）")
    }

    static func listSequences() throws {
        let sequences = SequenceStore.loadAll()
        guard !sequences.isEmpty else {
            print("无已保存序列（App 录制后保存在 ~/Library/Application Support/QianShou/sequences/）")
            return
        }
        print("已保存序列:")
        for seq in sequences {
            print("  \(seq.name) — \(seq.points.count) 动作 · \(String(format: "%.1f", Double(seq.durationMs) / 1000))s × \(seq.loops) 轮")
        }
        print("回放: qianshou run <以上任一文件的完整路径>")
    }

    static func printUsage() {
        print("""
        千手 CLI — iOS 模拟器自动化脚本

        用法:
          qianshou run <sequence.json> [--loops N]   回放点击序列（可循环）
          qianshou run <flow.yaml>                   执行 YAML flow 脚本
          qianshou list                               列出已保存序列

        前置条件:
          1. 模拟器已启动（xcrun simctl boot <udid>）
          2. WDA 触摸注入已运行（./Scripts/start_wda.sh）

        flow 脚本示例（examples/settings-browse.yaml）:
          appId: com.apple.Preferences
          ---
          - launchApp
          - tapOn: "通用"
          - assertVisible: "关于本机"

        示例:
          qianshou run examples/demo-settings-browse.json
          qianshou run examples/settings-browse.yaml
          qianshou run examples/demo-smoke-flow.json --loops 3
        """)
    }
}
