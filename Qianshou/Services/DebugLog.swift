import Foundation

/// 调试日志：写文件到 /tmp/qianshou_debug.log（GUI App 的 stdout/log show 不可靠，文件最稳）
enum DebugLog {
    static let url = URL(fileURLWithPath: "/tmp/qianshou_debug.log")

    static func log(_ message: String, file: String = #file, line: Int = #line) {
        let line = "[\(Date())] \(message) (\((file as NSString).lastPathComponent):\(line))\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
        NSLog("%@", message)
    }
}
