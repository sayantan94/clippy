import AppKit

class DockPanel: NSPanel {
    let clippyView = ClippyView(frame: NSRect(x: 10, y: 10, width: 72, height: 72))
    private var animationTimer: Timer?

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
        isMovableByWindowBackground = true

        let containerView = DockContainerView(frame: contentRect(forFrameRect: frame))
        containerView.addSubview(clippyView)
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
}
