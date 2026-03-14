import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockPanel: DockPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dockPanel = DockPanel()
        dockPanel?.orderFront(nil)
    }
}
