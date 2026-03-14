import Foundation

public struct Rule: Codable {
    public let name: String
    public let pattern: String
    public let severity: CommandSeverity
    public let description: String

    public var regex: NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [])
    }
}

public struct AIToolDefinition: Codable {
    public let name: String
    public let processName: String
    public let stopSignal: String

    enum CodingKeys: String, CodingKey {
        case name
        case processName = "process_name"
        case stopSignal = "stop_signal"
    }
}

public struct RulesConfig: Codable {
    public let rules: [Rule]
    public let aiTools: [AIToolDefinition]

    enum CodingKeys: String, CodingKey {
        case rules
        case aiTools = "ai_tools"
    }
}
