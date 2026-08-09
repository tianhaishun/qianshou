import Foundation

/// AI 动作序列 → 可复现 flow 脚本（纯序列化，可单测）
///
/// 映射：tapElement → tapOn text；tapPoint → tapOn point；
/// type → inputText；swipe → swipe 百分比；pressHome → pressKey HOME。
/// 元素定位优先（label），坐标点击转百分比（换机型不失效）。
enum FlowExporter {

    /// AI 执行动作记录
    enum Action {
        case tapElement(label: String)
        case tapPoint(xPct: Double, yPct: Double)
        case type(text: String)
        case swipe(fxPct: Double, fyPct: Double, txPct: Double, tyPct: Double)
        case pressHome
    }

    /// 序列化为 YAML flow（YAMLParser 可直接解析回 FlowCommand）
    static func yaml(from actions: [Action]) -> String {
        guard !actions.isEmpty else { return "" }
        var lines = [
            "# 由千手 AI 生成 —— 可复现脚本",
            "---",
        ]
        for action in actions {
            switch action {
            case .tapElement(let label):
                lines.append("- tapOn: \"\(escape(label))\"")
            case .tapPoint(let x, let y):
                lines.append("- tapOn:")
                lines.append("    point: \"\(Int(x))%, \(Int(y))%\"")
            case .type(let text):
                lines.append("- inputText: \"\(escape(text))\"")
            case .swipe(let fx, let fy, let tx, let ty):
                lines.append("- swipe:")
                lines.append("    start: \"\(Int(fx))%, \(Int(fy))%\"")
                lines.append("    end: \"\(Int(tx))%, \(Int(ty))%\"")
            case .pressHome:
                lines.append("- pressKey: HOME")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// YAML 双引号字符串转义（引号/反斜杠/换行/控制符）
    static func escape(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(ch)
            }
        }
        return out
    }
}
