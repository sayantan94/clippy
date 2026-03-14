import Foundation
import ClippyShared

class XPCClient {
    private var connection: NSXPCConnection?

    func connect() {
        let conn = NSXPCConnection(machServiceName: clippyHelperMachServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: ClippyHelperProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: ClippyAppProtocol.self)
        conn.exportedObject = AppEventHandler()

        conn.invalidationHandler = { [weak self] in
            print("[App] XPC connection invalidated")
            self?.connection = nil
        }

        conn.resume()
        self.connection = conn
    }

    var helper: ClippyHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { error in
            print("[App] XPC error: \(error)")
        } as? ClippyHelperProtocol
    }

    func watchTerminal(pid: Int32, completion: @escaping (Bool) -> Void) {
        helper?.watchTerminal(pid: pid, reply: completion)
    }

    func unwatchTerminal(pid: Int32) {
        helper?.unwatchTerminal(pid: pid)
    }
}

class AppEventHandler: NSObject, ClippyAppProtocol {
    func commandDetected(_ data: Data) {
        guard let event = try? JSONDecoder().decode(ClippyExecEvent.self, from: data) else { return }
        NotificationCenter.default.post(name: .clippyCommandDetected, object: event)
    }

    func commandBlocked(_ data: Data) {
        guard let event = try? JSONDecoder().decode(ClippyExecEvent.self, from: data) else { return }
        NotificationCenter.default.post(name: .clippyCommandBlocked, object: event)
    }
}

extension Notification.Name {
    static let clippyCommandDetected = Notification.Name("clippyCommandDetected")
    static let clippyCommandBlocked = Notification.Name("clippyCommandBlocked")
}
