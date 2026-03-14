import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockPanel: DockPanel?
    let sessionManager = SessionManager()
    var clippyPanels: [pid_t: ClippyPanel] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dockPanel = DockPanel()
        dockPanel?.onDropOnTerminal = { [weak self] terminalInfo in
            self?.attachClippy(to: terminalInfo)
        }
        dockPanel?.orderFront(nil)
    }

    private func attachClippy(to terminal: TerminalInfo) {
        guard !sessionManager.isWatching(terminalPid: terminal.pid) else { return }

        let panel = ClippyPanel(terminalInfo: terminal)
        panel.orderFront(nil)
        clippyPanels[terminal.pid] = panel
        _ = sessionManager.startSession(terminalPid: terminal.pid)
    }
}
