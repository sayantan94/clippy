import Foundation
import ClippyShared

#if canImport(EndpointSecurity)
import EndpointSecurity

class ESMonitor {
    private var client: OpaquePointer?
    private var watchedPids: Set<pid_t> = []
    private let ruleEngine: RuleEngine
    private let auditLogger: AuditLogger
    var onCommandDetected: ((ClippyExecEvent) -> Void)?
    var onCommandBlocked: ((ClippyExecEvent) -> Void)?

    init(ruleEngine: RuleEngine, auditLogger: AuditLogger) {
        self.ruleEngine = ruleEngine
        self.auditLogger = auditLogger
    }

    func start() -> Bool {
        let result = es_new_client(&client) { [weak self] _, message in
            self?.handleEvent(message: message)
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let client = client else {
            print("[ESMonitor] Failed to create ES client: \(result.rawValue)")
            return false
        }

        var events: [es_event_type_t] = [ES_EVENT_TYPE_NOTIFY_EXEC]
        let subResult = es_subscribe(client, &events, UInt32(events.count))
        guard subResult == ES_RETURN_SUCCESS else {
            print("[ESMonitor] Failed to subscribe: \(subResult.rawValue)")
            return false
        }

        print("[ESMonitor] Started successfully")
        return true
    }

    func stop() {
        guard let client = client else { return }
        es_unsubscribe_all(client)
        es_delete_client(client)
        self.client = nil
    }

    func watchPid(_ pid: pid_t) {
        watchedPids.insert(pid)
    }

    func unwatchPid(_ pid: pid_t) {
        watchedPids.remove(pid)
    }

    private func handleEvent(message: UnsafePointer<es_message_t>) {
        guard message.pointee.event_type == ES_EVENT_TYPE_NOTIFY_EXEC else { return }

        let process = message.pointee.event.exec.target.pointee
        let pid = audit_token_to_pid(process.audit_token)

        guard let terminalPid = ProcessInspector.isDescendantOf(pid: pid, ancestors: watchedPids) else {
            return
        }

        let execPath = String(cString: process.executable.pointee.path.data)
        let command = (execPath as NSString).lastPathComponent
        let args = ProcessInspector.getCommandLine(pid: pid) ?? [command]
        let fullCommand = args.joined(separator: " ")

        let matchedRule = ruleEngine.match(command: fullCommand)
        let severity = matchedRule?.severity ?? .info

        let event = ClippyExecEvent(
            pid: pid,
            terminalPid: terminalPid,
            command: command,
            arguments: Array(args.dropFirst()),
            severity: severity,
            matchedRule: matchedRule?.name
        )

        switch severity {
        case .critical:
            kill(pid, SIGTSTP)
            auditLogger.log(event: event, action: "blocked")
            onCommandBlocked?(event)
        case .warning:
            auditLogger.log(event: event, action: "warned")
            onCommandDetected?(event)
        case .info:
            auditLogger.log(event: event, action: "logged")
            onCommandDetected?(event)
        }
    }
}

#else

// Stub implementation when EndpointSecurity framework is not available
class ESMonitor {
    private var watchedPids: Set<pid_t> = []
    private let ruleEngine: RuleEngine
    private let auditLogger: AuditLogger
    var onCommandDetected: ((ClippyExecEvent) -> Void)?
    var onCommandBlocked: ((ClippyExecEvent) -> Void)?

    init(ruleEngine: RuleEngine, auditLogger: AuditLogger) {
        self.ruleEngine = ruleEngine
        self.auditLogger = auditLogger
    }

    func start() -> Bool {
        print("[ESMonitor] EndpointSecurity framework not available on this platform")
        return false
    }

    func stop() {}

    func watchPid(_ pid: pid_t) {
        watchedPids.insert(pid)
    }

    func unwatchPid(_ pid: pid_t) {
        watchedPids.remove(pid)
    }
}

#endif
