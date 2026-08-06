import Foundation

/// 序列持久化：保存/加载/列出到 AppSupport/sequences/
enum SequenceStore {

    static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QianShou", isDirectory: true)
            .appendingPathComponent("sequences", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save(_ sequence: ClickSequence) throws -> URL {
        let safeName = sequence.name.replacingOccurrences(of: "/", with: "-")
        let url = directory.appendingPathComponent("\(safeName).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // 原子写：先写临时文件再替换，避免中途崩溃留下损坏 JSON
        let tmpURL = url.appendingPathExtension("tmp")
        try encoder.encode(sequence).write(to: tmpURL)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        return url
    }

    static func loadAll() -> [ClickSequence] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(ClickSequence.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    static func delete(_ sequence: ClickSequence) {
        let url = directory.appendingPathComponent("\(sequence.name.replacingOccurrences(of: "/", with: "-")).json")
        try? FileManager.default.removeItem(at: url)
    }
}
