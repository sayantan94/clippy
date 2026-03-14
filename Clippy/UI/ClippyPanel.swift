import AppKit

class ClippyPanel: NSPanel {
    let clippyView = ClippyView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))
    let terminalInfo: TerminalInfo
    private var animationTimer: Timer?
    var onClicked: (() -> Void)?

    init(terminalInfo: TerminalInfo) {
        self.terminalInfo = terminalInfo
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 72, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces]

        contentView = clippyView
        clippyView.state = .watching

        startAnimation()
        snapToTerminal()
    }

    func snapToTerminal() {
        let termFrame = terminalInfo.windowFrame
        // Position at top-right corner of terminal (screen coordinates, Y flipped for AppKit)
        let screenHeight = NSScreen.main?.frame.height ?? 900
        let x = termFrame.maxX - 36  // half-overlapping the edge
        let y = screenHeight - termFrame.minY - 36
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override func mouseDown(with event: NSEvent) {
        onClicked?()
    }

    func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.clippyView.tick()
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}
