import Foundation

/// 零依赖 YAML 子集解析器
///
/// 只解析 flow 脚本需要的结构（Maestro 兼容子集）：
/// - 缩进块（统一缩进即可，不限 2/4 空格）
/// - `key: value` 映射、`- item` 列表
/// - 标量：单/双引号字符串、数字、布尔、裸字符串
/// - `#` 行注释、`---` 文档分隔符（分隔符前的部分视为 header map）
///
/// 不支持：锚点/别名、多行块标量、流式 `{a: 1}`、`${}` 表达式求值。
enum YAMLParser {

    enum ParseError: LocalizedError {
        case unexpectedIndent(Int, String)
        case malformedLine(String)

        var errorDescription: String? {
            switch self {
            case .unexpectedIndent(let indent, let line): return "缩进异常（\(indent)）: \(line)"
            case .malformedLine(let line): return "无法解析的行: \(line)"
            }
        }
    }

    /// 通用 YAML 值树
    indirect enum Value: Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case list([Value])
        case map([String: Value])
        case null

        var stringValue: String? {
            if case .string(let s) = self { return s }
            if case .number(let n) = self { return n == n.rounded() ? String(Int(n)) : String(n) }
            return nil
        }
    }

    struct Document {
        /// `---` 前的 header（appId/name 等），可为空
        let header: [String: Value]
        /// 主内容（commands 列表或根 map）
        let root: Value
    }

    // MARK: - 解析入口

    /// 解析整份 YAML。返回 header + root。
    static func parse(_ text: String) throws -> Document {
        // 预处理：去 \r、去注释（# 开头或空格后 #，但不处理引号内的 #——子集内接受简化）
        // 先扫描是否含 --- 分隔符：无分隔符 → 全部为 body；有 → 分隔符前为 header
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let hasSeparator = rawLines.contains {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }
        var headerLines: [String] = []
        var bodyLines: [String] = []
        var inBody = !hasSeparator

        for rawLine in rawLines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                inBody = true
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            // 行内注释：剥离 # 前的内容（简化：不处理引号内的 #）
            let content: String
            if let hashIdx = line.firstIndex(of: "#") {
                content = String(line[..<hashIdx])
                if content.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            } else {
                content = line
            }
            if inBody { bodyLines.append(content) } else { headerLines.append(content) }
        }

        let header = headerLines.isEmpty ? [:] : try blockMap(parseBlocks(headerLines))
        let blocks = try parseBlocks(bodyLines)
        let root: Value
        if blocks.isEmpty {
            root = .null
        } else if blocks.allSatisfy({ $0.content.hasPrefix("-") }) {
            // 顶层全是列表项 → 列表
            root = try blockList(blocks)
        } else {
            root = try blockValue(blocks[0])
        }
        return Document(header: header, root: root)
    }

    // MARK: - 块树

    /// 缩进块：内容行 + 其子块
    private struct Block {
        let indent: Int
        let content: String
        let children: [Block]
    }

    /// 按缩进把行组织成块树（递归分组：同缩进为兄弟，更大缩进为子块）
    private static func parseBlocks(_ lines: [String]) throws -> [Block] {
        let parsed: [(indent: Int, content: String)] = lines.compactMap { line in
            let indent = line.prefix(while: { $0 == " " }).count
            let content = String(line.dropFirst(indent))
            return content.isEmpty ? nil : (indent, content)
        }
        return groupBlocks(parsed)
    }

    /// 递归分组：首行缩进为基准，相同缩进为兄弟块，更大缩进归入当前块的 children
    private static func groupBlocks(_ lines: [(indent: Int, content: String)]) -> [Block] {
        guard let first = lines.first else { return [] }
        let base = first.indent
        var blocks: [Block] = []
        var i = 0
        while i < lines.count {
            let (indent, content) = lines[i]
            guard indent >= base else { break }
            if indent > base {
                // 孤儿缩进行（容错：提升一层）
                i += 1
                continue
            }
            var j = i + 1
            while j < lines.count && lines[j].indent > base { j += 1 }
            let children = groupBlocks(Array(lines[(i + 1)..<j]))
            blocks.append(Block(indent: indent, content: content, children: children))
            i = j
        }
        return blocks
    }

    // MARK: - 值构建

    /// 块 → 值：块首行是 `key:`/`- x` 时继续按子块展开
    private static func blockValue(_ block: Block) throws -> Value {
        let c = block.content
        if c.hasPrefix("-") {
            // 列表项
            return try listValue(block)
        }
        if let colonIdx = findColon(in: c) {
            let key = String(c[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(c[c.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            if rawValue.isEmpty {
                // map（值来自子块）
                return .map([key: try childrenValue(block.children)])
            }
            // 标量或嵌套 map
            return .map([key: try scalarOrNested(rawValue, block)])
        }
        // 裸标量
        return scalar(c)
    }

    private static func scalarOrNested(_ raw: String, _ block: Block) throws -> Value {
        if raw.isEmpty {
            if block.children.isEmpty { return .null }
            let child = block.children[0]
            return try blockValue(child)
        }
        return scalar(raw)
    }

    /// 子块 → 值：全是 `-` 项 → 列表；全是 key: value → 合并 map；否则取首个块值
    private static func childrenValue(_ children: [Block]) throws -> Value {
        guard let first = children.first else { return .null }
        if children.allSatisfy({ $0.content.hasPrefix("-") }) {
            return try blockList(children)
        }
        var maps: [String: Value] = [:]
        for child in children {
            if case .map(let m) = try blockValue(child) {
                maps.merge(m) { $1 }
            } else {
                return try blockValue(first)
            }
        }
        return .map(maps)
    }

    /// 块列表（每个块一个列表项）
    private static func blockList(_ blocks: [Block]) throws -> Value {
        var items: [Value] = []
        for block in blocks {
            items.append(try blockValue(block))
        }
        return .list(items)
    }

    /// 列表项块：`- x` 或 `- x: y`
    private static func listValue(_ block: Block) throws -> Value {
        var c = block.content
        c.removeFirst() // '-'
        let rest = c.trimmingCharacters(in: .whitespaces)

        if rest.isEmpty {
            // `-` 后无内容：值来自子块
            if block.children.isEmpty { return .null }
            return try blockValue(block.children[0])
        }
        if let colonIdx = findColon(in: rest) {
            let key = String(rest[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(rest[rest.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            if rawValue.isEmpty {
                // `- key:` → map，值来自子块
                return .map([key: try childrenValue(block.children)])
            }
            // `- key: value` → map（若子块还有内容则继续合并）
            var map: [String: Value] = [key: scalar(rawValue)]
            for child in block.children {
                if let v = try? blockMap([child]) { map.merge(v) { $1 } }
            }
            return .map(map)
        }
        // `- 标量`
        return scalar(rest)
    }

    /// 块 map：每块一个 key: value
    private static func blockMap(_ blocks: [Block]) throws -> [String: Value] {
        var map: [String: Value] = [:]
        for block in blocks {
            let v = try blockValue(block)
            if case .map(let m) = v {
                map.merge(m) { $1 }
            } else {
                throw ParseError.malformedLine(block.content)
            }
        }
        return map
    }

    // MARK: - 标量

    /// 标量解析：引号字符串 / 数字 / 布尔 / 裸字符串
    private static func scalar(_ raw: String) -> Value {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return .null }
        if s.count >= 2 {
            if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
                return .string(String(s.dropFirst().dropLast()))
            }
        }
        if s == "true" { return .bool(true) }
        if s == "false" { return .bool(false) }
        if let n = Double(s), !s.contains(",") { return .number(n) }
        return .string(s)
    }

    /// 找第一个结构冒号（不在引号内的 `:`）
    private static func findColon(in s: String) -> String.Index? {
        var inQuote: Character? = nil
        for (i, ch) in s.enumerated() {
            if let q = inQuote {
                if ch == q { inQuote = nil }
                continue
            }
            if ch == "\"" || ch == "'" { inQuote = ch; continue }
            if ch == ":" {
                // 冒号后必须是空格或行尾，否则是 URL 等（如 "https://"）
                let after = s.index(s.startIndex, offsetBy: i + 1)
                if after == s.endIndex || s[after] == " " { return s.index(s.startIndex, offsetBy: i) }
            }
        }
        return nil
    }
}
