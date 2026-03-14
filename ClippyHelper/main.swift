import Foundation
import ClippyShared

// Load rules
let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
let rulesPath = homeDir + "/.clippy/rules.yaml"

let ruleEngine: RuleEngine
if FileManager.default.fileExists(atPath: rulesPath) {
    ruleEngine = try RuleEngine(filePath: rulesPath)
} else {
    // Fallback: create minimal rule engine
    let fallbackYaml = """
    rules: []
    ai_tools: []
    """
    ruleEngine = try RuleEngine(yaml: fallbackYaml)
    print("[Helper] No rules.yaml found at \(rulesPath), running with empty rules")
}

let auditLogger = AuditLogger(filePath: homeDir + "/.clippy/audit.log")

// Set up ES Monitor
let monitor = ESMonitor(ruleEngine: ruleEngine, auditLogger: auditLogger)

// Set up XPC
let handler = HelperCommandHandler()
handler.onWatch = { pid in monitor.watchPid(pid) }
handler.onUnwatch = { pid in monitor.unwatchPid(pid) }

let delegate = HelperXPCDelegate(handler: handler)
let listener = NSXPCListener(machServiceName: clippyHelperMachServiceName)
listener.delegate = delegate
listener.resume()

// Start ES monitoring
if !monitor.start() {
    print("[Helper] Endpoint Security not available (requires root + entitlement)")
    print("[Helper] Running in passive mode")
}

print("[Helper] Running...")
RunLoop.current.run()
