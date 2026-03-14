import XCTest
@testable import ClippyShared

final class RuleEngineTests: XCTestCase {

    let sampleYAML = """
    rules:
      - name: destructive-rm
        pattern: "rm\\\\s+(-[a-zA-Z]*f[a-zA-Z]*\\\\s+|.*--no-preserve-root)"
        severity: critical
        description: "Recursive force delete or no-preserve-root"
      - name: git-force-push
        pattern: "git\\\\s+push\\\\s+.*(-f|--force)"
        severity: warning
        description: "Force pushing to remote"
      - name: npm-global-install
        pattern: "npm\\\\s+install\\\\s+-g"
        severity: info
        description: "Global npm package installation"
    ai_tools:
      - name: claude
        process_name: "claude"
        stop_signal: SIGTSTP
    """

    func testLoadRulesFromYAML() throws {
        let engine = try RuleEngine(yaml: sampleYAML)
        XCTAssertEqual(engine.rules.count, 3)
        XCTAssertEqual(engine.rules[0].name, "destructive-rm")
        XCTAssertEqual(engine.rules[1].name, "git-force-push")
        XCTAssertEqual(engine.rules[2].name, "npm-global-install")
        XCTAssertEqual(engine.aiTools.count, 1)
        XCTAssertEqual(engine.aiTools[0].name, "claude")
        XCTAssertEqual(engine.aiTools[0].processName, "claude")
        XCTAssertEqual(engine.aiTools[0].stopSignal, "SIGTSTP")
    }

    func testMatchCriticalCommand() throws {
        let engine = try RuleEngine(yaml: sampleYAML)
        let result = engine.match(command: "rm -rf /")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "destructive-rm")
        XCTAssertEqual(result?.severity, .critical)
    }

    func testNoMatchForSafeCommand() throws {
        let engine = try RuleEngine(yaml: sampleYAML)
        let result = engine.match(command: "ls -la")
        XCTAssertNil(result)
    }

    func testMatchReturnsHighestSeverity() throws {
        // YAML where a command could match both a warning and a critical rule
        let yaml = """
        rules:
          - name: info-rule
            pattern: "npm\\\\s+install"
            severity: info
            description: "npm install"
          - name: warning-rule
            pattern: "npm\\\\s+install\\\\s+-g"
            severity: warning
            description: "Global npm install"
          - name: critical-rule
            pattern: "npm\\\\s+install\\\\s+-g\\\\s+malware"
            severity: critical
            description: "Installing known malware"
        ai_tools: []
        """
        let engine = try RuleEngine(yaml: yaml)

        // "npm install -g malware" should match all three, but return critical
        let result = engine.match(command: "npm install -g malware")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.severity, .critical)
        XCTAssertEqual(result?.name, "critical-rule")
    }

    func testLoadFromFile() throws {
        let yaml = """
        rules:
          - name: test-rule
            pattern: "echo\\\\s+hello"
            severity: info
            description: "Test rule"
        ai_tools: []
        """
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("test-rules-\(UUID().uuidString).yaml").path
        try yaml.write(toFile: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: filePath) }

        let engine = try RuleEngine(filePath: filePath)
        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules[0].name, "test-rule")

        let result = engine.match(command: "echo hello")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "test-rule")
    }
}
