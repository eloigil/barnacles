// Draws the Barnacles app icon and writes a 1024px PNG.
// Usage: swift make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// One barnacle: a ridged cone with an opening on top, sitting at `base`.
func drawBarnacle(base: NSPoint, width w: CGFloat, height h: CGFloat) {
    let top = w * 0.42
    let shell = NSBezierPath()
    shell.move(to: NSPoint(x: base.x - w / 2, y: base.y))
    shell.curve(to: NSPoint(x: base.x - top / 2, y: base.y + h),
                controlPoint1: NSPoint(x: base.x - w * 0.46, y: base.y + h * 0.55),
                controlPoint2: NSPoint(x: base.x - top * 0.62, y: base.y + h * 0.9))
    shell.line(to: NSPoint(x: base.x + top / 2, y: base.y + h))
    shell.curve(to: NSPoint(x: base.x + w / 2, y: base.y),
                controlPoint1: NSPoint(x: base.x + top * 0.62, y: base.y + h * 0.9),
                controlPoint2: NSPoint(x: base.x + w * 0.46, y: base.y + h * 0.55))
    shell.close()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x02202B, 0.45)
    shadow.shadowOffset = NSSize(width: 0, height: -w * 0.05)
    shadow.shadowBlurRadius = w * 0.08
    shadow.set()
    NSGradient(starting: color(0xFFF6E8), ending: color(0xE6CFAE))!.draw(in: shell, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Ridges
    NSGraphicsContext.saveGraphicsState()
    shell.addClip()
    color(0xC9AD86, 0.9).setStroke()
    for i in 1...4 {
        let t = CGFloat(i) / 5
        let ridge = NSBezierPath()
        ridge.lineWidth = w * 0.025
        ridge.lineCapStyle = .round
        ridge.move(to: NSPoint(x: base.x - w / 2 + w * t, y: base.y - 2))
        ridge.line(to: NSPoint(x: base.x - top / 2 + top * t, y: base.y + h))
        ridge.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Opening
    let opening = NSRect(x: base.x - top * 0.42, y: base.y + h - top * 0.16, width: top * 0.84, height: top * 0.32)
    color(0x0B3B4A).setFill()
    NSBezierPath(ovalIn: opening).fill()
    color(0xFFFFFF, 0.5).setStroke()
    let rim = NSBezierPath(ovalIn: opening.insetBy(dx: -w * 0.012, dy: -w * 0.012))
    rim.lineWidth = w * 0.02
    rim.stroke()
}

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // macOS icon grid: 824px rounded square centred in 1024.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = NSColor(white: 0, alpha: 0.3)
    drop.shadowOffset = NSSize(width: 0, height: -10)
    drop.shadowBlurRadius = 24
    drop.set()
    color(0x0E4D64).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(starting: color(0x1FB5A8), ending: color(0x0B4F6C))!.draw(in: tile, angle: -90)

    // Rock the barnacles sit on
    let rock = NSBezierPath()
    rock.move(to: NSPoint(x: 100, y: 330))
    rock.curve(to: NSPoint(x: 924, y: 300),
               controlPoint1: NSPoint(x: 360, y: 400), controlPoint2: NSPoint(x: 680, y: 250))
    rock.line(to: NSPoint(x: 924, y: 100))
    rock.line(to: NSPoint(x: 100, y: 100))
    rock.close()
    NSGradient(starting: color(0x2D4A57), ending: color(0x1A2E37))!.draw(in: rock, angle: -90)

    drawBarnacle(base: NSPoint(x: 330, y: 330), width: 250, height: 230)
    drawBarnacle(base: NSPoint(x: 700, y: 290), width: 210, height: 190)
    drawBarnacle(base: NSPoint(x: 510, y: 300), width: 330, height: 330)
    NSGraphicsContext.restoreGraphicsState()
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { fatalError("couldn't render icon") }
try png.write(to: URL(fileURLWithPath: out))
