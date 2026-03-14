import Foundation

public final class AuditLogger {
    private let filePath: String
    private let dateFormatter: ISO8601DateFormatter

    public init(filePath: String) {
        self.filePath = filePath
        self.dateFormatter = ISO8601DateFormatter()
        // Ensure parent directory exists
        let dir = (filePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    public func log(event: ClippyExecEvent, action: String) {
        let timestamp = dateFormatter.string(from: event.timestamp)
        let fullCommand = ([event.command] + event.arguments).joined(separator: " ")
        let ruleName = event.matchedRule ?? "-"
        let line = "\(timestamp) | TERM:\(event.terminalPid) | \(event.severity.rawValue.uppercased()) | \(ruleName) | \(fullCommand) | \(action)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: filePath) {
                if let handle = FileHandle(forWritingAtPath: filePath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: filePath, contents: data)
            }
        }
    }
}
