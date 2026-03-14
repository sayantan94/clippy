import Foundation
import Yams

public final class RuleEngine {
    public private(set) var rules: [Rule]
    public private(set) var aiTools: [AIToolDefinition]

    public init(yaml: String) throws {
        let config = try YAMLDecoder().decode(RulesConfig.self, from: yaml)
        self.rules = config.rules
        self.aiTools = config.aiTools
    }

    public init(filePath: String) throws {
        let yaml = try String(contentsOfFile: filePath, encoding: .utf8)
        let config = try YAMLDecoder().decode(RulesConfig.self, from: yaml)
        self.rules = config.rules
        self.aiTools = config.aiTools
    }

    public func match(command: String) -> Rule? {
        let severityOrder: [CommandSeverity] = [.critical, .warning, .info]
        var bestMatch: Rule? = nil
        var bestIndex = severityOrder.count

        for rule in rules {
            guard let regex = rule.regex else { continue }
            let range = NSRange(command.startIndex..., in: command)
            if regex.firstMatch(in: command, range: range) != nil {
                let index = severityOrder.firstIndex(of: rule.severity) ?? severityOrder.count
                if index < bestIndex {
                    bestIndex = index
                    bestMatch = rule
                }
            }
        }
        return bestMatch
    }

    public func reload(filePath: String) throws {
        let yaml = try String(contentsOfFile: filePath, encoding: .utf8)
        let config = try YAMLDecoder().decode(RulesConfig.self, from: yaml)
        self.rules = config.rules
        self.aiTools = config.aiTools
    }
}
