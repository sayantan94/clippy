import XCTest
@testable import ClippyShared

final class ClippyEventTests: XCTestCase {
    func testEventCreation() {
        let event = ClippyExecEvent(
            pid: 123, terminalPid: 456,
            command: "ls", arguments: ["-la"],
            severity: .info, matchedRule: nil
        )
        XCTAssertEqual(event.pid, 123)
        XCTAssertEqual(event.command, "ls")
        XCTAssertEqual(event.severity, .info)
    }

    func testEventCodable() throws {
        let event = ClippyExecEvent(
            pid: 123, terminalPid: 456,
            command: "rm", arguments: ["-rf", "/"],
            severity: .critical, matchedRule: "destructive-rm"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ClippyExecEvent.self, from: data)
        XCTAssertEqual(decoded.command, "rm")
        XCTAssertEqual(decoded.severity, .critical)
        XCTAssertEqual(decoded.matchedRule, "destructive-rm")
    }
}
