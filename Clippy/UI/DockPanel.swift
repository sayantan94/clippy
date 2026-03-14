import AppKit

class DockPanel: NSPanel {
    let clippyView = ClippyView(frame: NSRect(x: 10, y: 10, width: 72, height: 72))
    private var animationTimer: Timer?
    var onDropOnTerminal: ((TerminalInfo) -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 92, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false  // We handle mouse events ourselves

        let containerView = DockContainerView(frame: contentRect(forFrameRect: frame))
        containerView.addSubview(clippyView)
        containerView.dockPanel = self
        contentView = containerView

        // Position in top-right area of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - frame.width - 20
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        startAnimation()
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.clippyView.tick()
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}

class DockContainerView: NSView {
    weak var dockPanel: DockPanel?
    private var isDragging = false
    private var dragGhostWindow: NSWindow?
    private var dragGhostView: ClippyView?

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)

        NSColor(white: 0.08, alpha: 0.95).setFill()
        path.fill()

        NSColor(white: 0.2, alpha: 1.0).setStroke()
        path.lineWidth = 1
        path.stroke()

        // Label
        let label = "CLIPPY" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor(white: 0.5, alpha: 1.0)
        ]
        let labelSize = label.size(withAttributes: attrs)
        let labelX = (bounds.width - labelSize.width) / 2
        label.draw(at: NSPoint(x: labelX, y: bounds.height - labelSize.height - 8), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let clippyFrame = dockPanel?.clippyView.frame ?? .zero
        guard clippyFrame.contains(localPoint) else {
            super.mouseDown(with: event)
            return
        }
        isDragging = true
        dockPanel?.clippyView.state = .dragging
        createDragGhost(at: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let ghostWindow = dragGhostWindow else { return }

        // Move ghost to follow cursor
        let screenPoint = NSEvent.mouseLocation
        ghostWindow.setFrameOrigin(NSPoint(x: screenPoint.x - 36, y: screenPoint.y - 36))

        // Check if hovering over a terminal (use CG coordinates: flip Y)
        let screenHeight = NSScreen.main?.frame.height ?? 900
        let cgPoint = CGPoint(x: screenPoint.x, y: screenHeight - screenPoint.y)
        if TerminalDetector.terminalAtPoint(cgPoint) != nil {
            dragGhostView?.state = .hovering
        } else {
            dragGhostView?.state = .dragging
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        dockPanel?.clippyView.state = .idle

        let screenPoint = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 900
        let cgPoint = CGPoint(x: screenPoint.x, y: screenHeight - screenPoint.y)

        if let terminal = TerminalDetector.terminalAtPoint(cgPoint) {
            // Dropped on a terminal — fire callback
            removeDragGhost()
            dockPanel?.onDropOnTerminal?(terminal)
        } else {
            // Animate ghost back to dock, then remove
            animateGhostBack()
        }
    }

    private func createDragGhost(at event: NSEvent) {
        let ghostView = ClippyView(frame: NSRect(x: 0, y: 0, width: 72, height: 72))
        ghostView.state = .dragging

        let screenPoint = NSEvent.mouseLocation
        let ghostWin = NSWindow(
            contentRect: NSRect(x: screenPoint.x - 36, y: screenPoint.y - 36, width: 72, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        ghostWin.level = .floating
        ghostWin.isOpaque = false
        ghostWin.backgroundColor = .clear
        ghostWin.hasShadow = true
        ghostWin.contentView = ghostView
        ghostWin.alphaValue = 0.85
        ghostWin.orderFront(nil)

        dragGhostWindow = ghostWin
        dragGhostView = ghostView
    }

    private func removeDragGhost() {
        dragGhostWindow?.orderOut(nil)
        dragGhostWindow = nil
        dragGhostView = nil
    }

    private func animateGhostBack() {
        guard let ghostWindow = dragGhostWindow,
              let dockFrame = dockPanel?.frame else {
            removeDragGhost()
            return
        }

        let targetOrigin = NSPoint(
            x: dockFrame.midX - 36,
            y: dockFrame.midY - 36
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ghostWindow.animator().setFrameOrigin(targetOrigin)
            ghostWindow.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.removeDragGhost()
        })
    }
}
