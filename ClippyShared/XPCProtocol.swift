import Foundation

@objc public protocol ClippyHelperProtocol {
    func watchTerminal(pid: Int32, reply: @escaping (Bool) -> Void)
    func unwatchTerminal(pid: Int32)
    func updateRules(yamlPath: String)
    func ping(reply: @escaping (Bool) -> Void)
}

@objc public protocol ClippyAppProtocol {
    func commandDetected(_ data: Data)  // Encoded ClippyExecEvent
    func commandBlocked(_ data: Data)   // Encoded ClippyExecEvent
}

public let clippyHelperMachServiceName = "com.clippy.helper"
