import AppKit

enum ClippyState {
    case idle, dragging, hovering, watching, warning, blocking, allClear, blink
}

struct ClippyPalette {
    let outline: NSColor
    let shadow: NSColor
    let body: NSColor
    let light: NSColor
    let bright: NSColor
    let specular: NSColor

    static let silver = ClippyPalette(
        outline:  NSColor(hex: 0x222233),
        shadow:   NSColor(hex: 0x6A6A7A),
        body:     NSColor(hex: 0x9898A8),
        light:    NSColor(hex: 0xB8B8C8),
        bright:   NSColor(hex: 0xD0D0DD),
        specular: NSColor(hex: 0xEEEEF6)
    )

    static let red = ClippyPalette(
        outline:  NSColor(hex: 0x2A0C0C),
        shadow:   NSColor(hex: 0x7A2020),
        body:     NSColor(hex: 0xC83838),
        light:    NSColor(hex: 0xE85050),
        bright:   NSColor(hex: 0xF47070),
        specular: NSColor(hex: 0xFFA0A0)
    )

    static let green = ClippyPalette(
        outline:  NSColor(hex: 0x0C2A0C),
        shadow:   NSColor(hex: 0x1A6A1A),
        body:     NSColor(hex: 0x30A030),
        light:    NSColor(hex: 0x48C848),
        bright:   NSColor(hex: 0x68E068),
        specular: NSColor(hex: 0xA0F0A0)
    )
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

class SpriteRenderer {
    static let spriteSize = 48

    /// Render a Clippy sprite to an NSImage at the given state.
    /// Uses procedural pixel-art drawing — wire shape with metallic shading and crossing.
    static func render(state: ClippyState) -> NSImage {
        let palette: ClippyPalette
        switch state {
        case .blocking: palette = .red
        case .allClear: palette = .green
        default: palette = .silver
        }

        let size = NSSize(width: spriteSize, height: spriteSize)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none

        // Draw the paperclip wire shape
        drawWireShape(ctx: ctx, palette: palette)
        drawEyes(ctx: ctx, state: state, palette: palette)
        drawMouth(ctx: ctx, state: state, palette: palette)

        image.unlockFocus()
        return image
    }

    private static func drawWireShape(ctx: CGContext, palette: ClippyPalette) {
        // Vertical wire helper
        func vWire(_ x: Int, _ y1: Int, _ y2: Int) {
            for y in y1...y2 {
                px(ctx, x, y, palette.outline)
                px(ctx, x+1, y, palette.bright)
                px(ctx, x+2, y, palette.light)
                px(ctx, x+3, y, palette.body)
                px(ctx, x+4, y, palette.shadow)
                px(ctx, x+5, y, palette.outline)
                if y % 3 == 0 { px(ctx, x+1, y, palette.specular) }
            }
        }

        // Horizontal wire helper
        func hWire(_ y: Int, _ x1: Int, _ x2: Int) {
            for x in x1...x2 {
                px(ctx, x, y, palette.outline)
                px(ctx, x, y+1, palette.bright)
                px(ctx, x, y+2, palette.light)
                px(ctx, x, y+3, palette.body)
                px(ctx, x, y+4, palette.shadow)
                px(ctx, x, y+5, palette.outline)
                if x % 3 == 0 { px(ctx, x, y+1, palette.specular) }
            }
        }

        // Outer left (back layer)
        vWire(10, 7, 39)
        // Outer right
        vWire(34, 7, 20)
        // Top curve
        hWire(2, 16, 33)
        // Bottom curve
        hWire(39, 16, 27)
        // Inner descent
        hWire(20, 22, 33)
        vWire(22, 26, 36)
        // Inner bottom
        hWire(36, 28, 33)
        vWire(28, 36, 39)

        // Crossing: inner wire over outer left
        drawCrossing(ctx, 10, 25, palette)
    }

    private static func drawCrossing(_ ctx: CGContext, _ x: Int, _ y: Int, _ pal: ClippyPalette) {
        for dy in 0..<8 {
            // Back wire (dimmed)
            for dx in 0..<6 {
                px(ctx, x+dx, y+dy, pal.shadow)
            }
            px(ctx, x, y+dy, pal.outline)
            px(ctx, x+5, y+dy, pal.outline)
        }
        // Front wire crossing diagonally
        for i in 0..<8 {
            let fx = x - 2 + i
            let fy = y + i
            px(ctx, fx+1, fy+1, pal.outline)
            px(ctx, fx+2, fy+1, pal.outline)
            px(ctx, fx+3, fy+1, pal.outline)
            px(ctx, fx+4, fy+1, pal.outline)
            px(ctx, fx+5, fy+1, pal.outline)
            px(ctx, fx, fy, pal.outline)
            px(ctx, fx+1, fy, pal.bright)
            px(ctx, fx+2, fy, pal.light)
            px(ctx, fx+3, fy, pal.body)
            px(ctx, fx+4, fy, pal.shadow)
            px(ctx, fx+5, fy, pal.outline)
            if i % 2 == 0 { px(ctx, fx+1, fy, pal.specular) }
        }
    }

    private static func drawEyes(ctx: CGContext, state: ClippyState, palette: ClippyPalette) {
        let white = NSColor.white
        let pupil = NSColor(hex: 0x111122)

        func eye(_ ex: Int, _ ey: Int) {
            px(ctx, ex+1, ey, palette.outline)
            px(ctx, ex+2, ey, palette.outline)
            px(ctx, ex+3, ey, palette.outline)
            px(ctx, ex, ey+1, palette.outline)
            px(ctx, ex+1, ey+1, white)
            px(ctx, ex+2, ey+1, white)
            px(ctx, ex+3, ey+1, white)
            px(ctx, ex+4, ey+1, palette.outline)
            px(ctx, ex, ey+2, palette.outline)
            px(ctx, ex+1, ey+2, white)
            px(ctx, ex+2, ey+2, pupil)
            px(ctx, ex+3, ey+2, pupil)
            px(ctx, ex+4, ey+2, palette.outline)
            px(ctx, ex, ey+3, palette.outline)
            px(ctx, ex+1, ey+3, white)
            px(ctx, ex+2, ey+3, pupil)
            px(ctx, ex+3, ey+3, white)
            px(ctx, ex+4, ey+3, palette.outline)
            px(ctx, ex+1, ey+4, palette.outline)
            px(ctx, ex+2, ey+4, palette.outline)
            px(ctx, ex+3, ey+4, palette.outline)
        }

        switch state {
        case .blink:
            for ex in [14, 27] {
                px(ctx, ex+1, 9, palette.outline)
                px(ctx, ex+2, 9, palette.outline)
                px(ctx, ex+3, 9, palette.outline)
                px(ctx, ex, 10, palette.outline)
                px(ctx, ex+1, 10, palette.body)
                px(ctx, ex+2, 10, palette.body)
                px(ctx, ex+3, 10, palette.body)
                px(ctx, ex+4, 10, palette.outline)
                px(ctx, ex+1, 11, palette.outline)
                px(ctx, ex+2, 11, palette.outline)
                px(ctx, ex+3, 11, palette.outline)
            }
        case .blocking:
            eye(14, 8); eye(27, 8)
            // Angry brows
            px(ctx, 14, 7, palette.outline); px(ctx, 15, 7, palette.outline)
            px(ctx, 16, 8, palette.outline); px(ctx, 17, 8, palette.outline)
            px(ctx, 31, 7, palette.outline); px(ctx, 30, 7, palette.outline)
            px(ctx, 29, 8, palette.outline); px(ctx, 28, 8, palette.outline)
        case .allClear:
            for ex in [14, 27] {
                px(ctx, ex+1, 9, palette.outline); px(ctx, ex+2, 9, palette.outline); px(ctx, ex+3, 9, palette.outline)
                px(ctx, ex, 10, palette.outline); px(ctx, ex+4, 10, palette.outline)
                px(ctx, ex+1, 11, palette.outline); px(ctx, ex+2, 11, palette.outline); px(ctx, ex+3, 11, palette.outline)
            }
        default:
            eye(14, 8); eye(27, 8)
        }
    }

    private static func drawMouth(ctx: CGContext, state: ClippyState, palette: ClippyPalette) {
        let o = palette.outline
        switch state {
        case .blocking:
            px(ctx, 21, 15, o); px(ctx, 22, 15, o); px(ctx, 23, 15, o); px(ctx, 24, 15, o)
            px(ctx, 20, 16, o); px(ctx, 25, 16, o)
            px(ctx, 21, 17, o); px(ctx, 22, 17, o); px(ctx, 23, 17, o); px(ctx, 24, 17, o)
        case .allClear:
            px(ctx, 20, 15, o); px(ctx, 25, 15, o)
            px(ctx, 21, 16, o); px(ctx, 22, 16, o); px(ctx, 23, 16, o); px(ctx, 24, 16, o)
        default:
            px(ctx, 21, 15, o); px(ctx, 22, 15, o); px(ctx, 23, 15, o); px(ctx, 24, 15, o)
        }
    }

    /// Set a single pixel on the CGContext (y is flipped for AppKit coordinates)
    private static func px(_ ctx: CGContext, _ x: Int, _ y: Int, _ color: NSColor) {
        let flippedY = spriteSize - 1 - y  // flip for AppKit coordinate system
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: x, y: flippedY, width: 1, height: 1))
    }
}
