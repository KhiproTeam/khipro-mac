// Renders the DMG installer background (600x400 pt, drawn @2x) natively via AppKit/CoreGraphics.
// No external deps. Usage: swift make-bg.swift <out.png>
// Icon centers (set in create-dmg.sh): app at (120,170), Input Methods at (480,170), top-origin.
import AppKit

let W = 600.0, H = 400.0, S = 2.0
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-bg.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * S), pixelsHigh: Int(H * S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H) // 144 dpi, so Finder shows it at 600x400 pt
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func ty(_ yTop: Double) -> Double { H - yTop }
let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// --- Backdrop: the logo's coral, diagonal. Mid-tone so Finder's labels read in light and dark. ---
let bg = CGGradient(colorsSpace: space, colors: [rgb(190, 94, 104), rgb(206, 132, 114)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: W, y: H), end: CGPoint(x: 0, y: 0), options: [])

// --- Soft glow behind each icon (no hard edges, so the filename labels stay legible) ---
let glow = CGGradient(colorsSpace: space, colors: [rgb(255, 255, 255, 0.38), rgb(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
for cx in [120.0, 480.0] {
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: cx, y: ty(170)), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: ty(170)), endRadius: 95, options: [])
}

func text(_ s: String, x: Double? = nil, yTop: Double, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) {
    let str = NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
    ])
    let sz = str.size()
    str.draw(at: NSPoint(x: x ?? (W - sz.width) / 2, y: ty(yTop) - sz.height))
}

// --- Header ---
text("Khipro", yTop: 26, size: 28, weight: .bold)
text("খিপ্রো  ·  Bangla input method for macOS", yTop: 62, size: 13, weight: .medium, alpha: 0.85)

// --- Slim arrow between the icons ---
let ay = ty(170)
ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.setStrokeColor(rgb(255, 255, 255, 0.9)); ctx.setLineWidth(3)
ctx.move(to: CGPoint(x: 230, y: ay)); ctx.addLine(to: CGPoint(x: 370, y: ay)); ctx.strokePath()
ctx.move(to: CGPoint(x: 356, y: ay + 11)); ctx.addLine(to: CGPoint(x: 372, y: ay)); ctx.addLine(to: CGPoint(x: 356, y: ay - 11)); ctx.strokePath()
text("Drag Khipro into Input Methods (asks for your password)", yTop: 132, size: 12, weight: .medium, alpha: 0.9)

// --- Steps pill (below the Finder filename labels) ---
let pill = CGRect(x: 60, y: ty(364), width: 480, height: 62)
ctx.setFillColor(rgb(0, 0, 0, 0.18))
ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.fillPath()
text("After copying, log out and back in. Then open", yTop: 310, size: 12, weight: .regular, alpha: 0.9)
text("System Settings ▸ Keyboard ▸ Input Sources ▸ +  ▸  Bangla ▸ Khipro", yTop: 332, size: 12, weight: .semibold)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
