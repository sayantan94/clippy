import XCTest
@testable import ClippyShared

final class AuditLoggerTests: XCTestCase {

    func testLogEntry() throws {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audit-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let logger = AuditLogger(filePath: tmpFile.path)
        let event = ClippyExecEvent(
            pid: 1234, terminalPid: 5678,
            command: "rm", arguments: ["-rf", "/"],
            severity: .critical, matchedRule: "destructive-rm"
        )
        logger.log(event: event, action: "blocked")

        let contents = try String(contentsOfFile: tmpFile.path, encoding: .utf8)
        XCTAssertTrue(contents.contains("rm"))
        XCTAssertTrue(contents.contains("CRITICAL"))
        XCTAssertTrue(contents.contains("blocked"))
        XCTAssertTrue(contents.contains("5678"))
    }

    func testMultipleEntries() throws {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audit-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let logger = AuditLogger(filePath: tmpFile.path)
        for i in 0..<3 {
            let event = ClippyExecEvent(
                pid: Int32(i), terminalPid: 100,
                command: "cmd\(i)", arguments: [],
                severity: .info, matchedRule: nil
            )
            logger.log(event: event, action: "logged")
        }

        let contents = try String(contentsOfFile: tmpFile.path, encoding: .utf8)
        let lines = contents.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3)
    }
}
