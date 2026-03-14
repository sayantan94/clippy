import Foundation

public enum CommandSeverity: String, Codable {
    case critical
    case warning
    case info
}

public struct ClippyExecEvent: Codable {
    public let pid: Int32
    public let terminalPid: Int32
    public let command: String
    public let arguments: [String]
    public let severity: CommandSeverity
    public let matchedRule: String?
    public let timestamp: Date

    public init(pid: Int32, terminalPid: Int32, command: String, arguments: [String],
                severity: CommandSeverity, matchedRule: String?, timestamp: Date = Date()) {
        self.pid = pid
        self.terminalPid = terminalPid
        self.command = command
        self.arguments = arguments
        self.severity = severity
        self.matchedRule = matchedRule
        self.timestamp = timestamp
    }
}
