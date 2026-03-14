import Foundation

struct BabysitSession {
    let terminalPid: pid_t
    let startedAt: Date
    var commandCount: Int = 0
    var blockedCount: Int = 0
}

class SessionManager {
    private(set) var sessions: [pid_t: BabysitSession] = [:]

    func startSession(terminalPid: pid_t) -> BabysitSession {
        let session = BabysitSession(terminalPid: terminalPid, startedAt: Date())
        sessions[terminalPid] = session
        return session
    }

    func endSession(terminalPid: pid_t) {
        sessions.removeValue(forKey: terminalPid)
    }

    func isWatching(terminalPid: pid_t) -> Bool {
        sessions[terminalPid] != nil
    }

    func incrementCommand(terminalPid: pid_t) {
        sessions[terminalPid]?.commandCount += 1
    }

    func incrementBlocked(terminalPid: pid_t) {
        sessions[terminalPid]?.blockedCount += 1
    }
}
