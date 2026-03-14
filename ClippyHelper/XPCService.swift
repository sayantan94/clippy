import Foundation
import ClippyShared

class HelperXPCDelegate: NSObject, NSXPCListenerDelegate {
    let handler: HelperCommandHandler

    init(handler: HelperCommandHandler) {
        self.handler = handler
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ClippyHelperProtocol.self)
        connection.exportedObject = handler
        connection.remoteObjectInterface = NSXPCInterface(with: ClippyAppProtocol.self)

        connection.invalidationHandler = {
            print("[Helper] XPC connection invalidated")
        }

        connection.resume()
        return true
    }
}

class HelperCommandHandler: NSObject, ClippyHelperProtocol {
    var watchedPids: Set<Int32> = []
    var onWatch: ((Int32) -> Void)?
    var onUnwatch: ((Int32) -> Void)?

    func watchTerminal(pid: Int32, reply: @escaping (Bool) -> Void) {
        watchedPids.insert(pid)
        onWatch?(pid)
        print("[Helper] Now watching terminal PID \(pid)")
        reply(true)
    }

    func unwatchTerminal(pid: Int32) {
        watchedPids.remove(pid)
        onUnwatch?(pid)
        print("[Helper] Stopped watching terminal PID \(pid)")
    }

    func updateRules(yamlPath: String) {
        print("[Helper] Rules updated from \(yamlPath)")
    }

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }
}
