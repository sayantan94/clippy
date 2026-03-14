import AppKit

struct TerminalInfo {
    let pid: pid_t
    let windowFrame: CGRect
    let bundleID: String
    let appName: String
}

class TerminalDetector {
    static let knownTerminals: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
    ]

    static func terminalAtPoint(_ point: CGPoint) -> TerminalInfo? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = window[kCGWindowOwnerName as String] as? String else {
                continue
            }

            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard frame.contains(point) else { continue }

            if let app = NSRunningApplication(processIdentifier: pid),
               let bundleID = app.bundleIdentifier,
               knownTerminals.contains(bundleID) {
                return TerminalInfo(
                    pid: pid,
                    windowFrame: frame,
                    bundleID: bundleID,
                    appName: ownerName
                )
            }
        }
        return nil
    }
}
