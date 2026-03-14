import AppKit

class ClippyView: NSView {
    var state: ClippyState = .idle {
        didSet { updateSprite() }
    }

    private var spriteLayer = CALayer()
    private var frameCounter = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(spriteLayer)
        updateSprite()
    }

    override func layout() {
        super.layout()
        spriteLayer.frame = bounds
    }

    func updateSprite() {
        let image = SpriteRenderer.render(state: state)
        spriteLayer.contents = image
    }

    /// Called by animation timer for blink
    func tick() {
        frameCounter += 1
        if state == .idle || state == .watching {
            let inBlink = (frameCounter % 180) > 174
            if inBlink {
                spriteLayer.contents = SpriteRenderer.render(state: .blink)
            } else {
                spriteLayer.contents = SpriteRenderer.render(state: state)
            }
        }
    }
}
