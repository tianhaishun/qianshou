import Foundation

/// 元素树解析 + 选择器匹配（App / CLI / AI 共用）
///
/// 从 WDA XML 提取可交互元素（有 label 或 identifier 的元素），
/// 归一化为内容区相对坐标（0-1），与设备分辨率解耦。
/// 兼容 WDA v16+（x/y/width/height 属性）与旧版（frame 属性）。
struct UIElement {
    let type: String
    let label: String
    let identifier: String
    /// 相对坐标（0-1，相对 XML 报告的屏幕尺寸）
    let relX: Double
    let relY: Double
    let relW: Double
    let relH: Double

    var centerX: Double { relX + relW / 2 }
    var centerY: Double { relY + relH / 2 }
}

enum ElementTree {

    /// 从 WDA XML 解析可交互元素（label 或 identifier 非空，截断前 60 个）
    ///
    /// 属性提取与顺序无关：先按标签切出属性串，再独立提取 label/identifier/
    /// x/y/width/height（新格式）或 frame（旧格式）。
    static func parse(_ xml: String) -> [UIElement] {
        let ns = xml as NSString
        let tagPattern = try! NSRegularExpression(pattern: #"<XCUIElementType(\w+)([^>]*)>"#)

        func group(_ match: NSTextCheckingResult, _ i: Int) -> String {
            let r = match.range(at: i)
            guard r.location != NSNotFound else { return "" }
            return ns.substring(with: r)
        }

        /// 从属性串提取 `key="value"`（顺序无关）
        func attr(_ key: String, in attrs: String) -> String? {
            let pattern = "(?:^|\\s)\(key)=\"([^\"]*)\""
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length)) else {
                return nil
            }
            let r = m.range(at: 1)
            guard r.location != NSNotFound else { return nil }
            return (attrs as NSString).substring(with: r)
        }

        // 屏幕尺寸（Application 元素；缺省 1x1）
        var screenW: Double = 1
        var screenH: Double = 1
        for match in tagPattern.matches(in: xml, range: NSRange(location: 0, length: ns.length)) where group(match, 1) == "Application" {
            let attrs = group(match, 2)
            if let w = attr("width", in: attrs), let h = attr("height", in: attrs) {
                screenW = max(Double(w) ?? 1, 1)
                screenH = max(Double(h) ?? 1, 1)
                break
            }
        }

        // 元素属性解析（新旧格式统一）
        func rect(of attrs: String) -> (x: Double, y: Double, w: Double, h: Double)? {
            // 新格式：x/y/width/height
            if let x = attr("x", in: attrs), let y = attr("y", in: attrs),
               let w = attr("width", in: attrs), let h = attr("height", in: attrs) {
                return (Double(x) ?? 0, Double(y) ?? 0, Double(w) ?? 0, Double(h) ?? 0)
            }
            // 旧格式：frame="{{x, y}, {w, h}}"
            if let frame = attr("frame", in: attrs) {
                let nums = frame.split(whereSeparator: { !$0.isNumber && $0 != "." })
                    .compactMap { Double($0) }
                guard nums.count >= 4 else { return nil }
                return (nums[0], nums[1], nums[2], nums[3])
            }
            return nil
        }

        var result: [UIElement] = []
        for match in tagPattern.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
            let type = group(match, 1)
            guard type != "Application" else { continue }
            let attrs = group(match, 2)
            let label = attr("label", in: attrs) ?? ""
            let identifier = attr("identifier", in: attrs) ?? ""
            guard !label.isEmpty || !identifier.isEmpty else { continue }
            guard let r = rect(of: attrs) else { continue }
            result.append(UIElement(
                type: type,
                label: label,
                identifier: identifier,
                relX: min(r.x / screenW, 1),
                relY: min(r.y / screenH, 1),
                relW: min(r.w / screenW, 1),
                relH: min(r.h / screenH, 1)
            ))
        }
        return Array(result.prefix(60))
    }

    /// 文本匹配：精确 → 子串（大小写不敏感兜底）
    static func textMatches(_ label: String, pattern: String) -> Bool {
        if label == pattern { return true }
        if label.hasPrefix("^") && label.hasSuffix("$") {
            let core = String(pattern.dropFirst().dropLast())
            return label == core || label.range(of: core, options: .regularExpression) != nil
        }
        if label.range(of: pattern, options: .caseInsensitive) != nil { return true }
        return label.localizedCaseInsensitiveContains(pattern)
    }

    /// 在元素列表中查找匹配选择器的元素（text 优先，其次 id）
    static func match(_ selector: FlowSelector, in elements: [UIElement]) -> UIElement? {
        if let text = selector.text {
            for el in elements where textMatches(el.label, pattern: text) { return el }
        }
        if let id = selector.id {
            for el in elements where el.identifier == id { return el }
        }
        return nil
    }

    /// 找到包含给定相对坐标的最小元素（录制时定位点击目标用）
    ///
    /// 深层元素优先：同一位置嵌套时取面积最小者（更具体）。
    static func element(atX px: Double, y py: Double, in elements: [UIElement]) -> UIElement? {
        var best: UIElement?
        var bestArea = Double.greatestFiniteMagnitude
        for el in elements {
            guard px >= el.relX, px <= el.relX + el.relW,
                  py >= el.relY, py <= el.relY + el.relH else { continue }
            let area = el.relW * el.relH
            if area < bestArea {
                bestArea = area
                best = el
            }
        }
        return best
    }
}
