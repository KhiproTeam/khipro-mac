import Cocoa
// Builds the input-source icon from logo.png: the logo's white mark becomes black-on-transparent.
// macOS treats input-source icons as templates (alpha only) and tints them, so an opaque tile shows as a blank box.
// Icons are 16pt: the Makefile builds 16px@72dpi and 32px@144dpi, then joins them into one TIFF (same as Apple's IMs).
// Usage: swift make-menu-icon.swift logo.png out.tiff pixels dpi
let a = CommandLine.arguments
let px = Int(a[3])!, dpi = Double(a[4])!
let big = 256 // threshold at high res, then downscale, so thin strokes keep their alpha

func bitmap(_ n: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4,
                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}
func draw(_ rep: NSBitmapImageRep, _ body: (NSRect) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    g.imageInterpolation = .high
    NSGraphicsContext.current = g
    body(NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
    NSGraphicsContext.restoreGraphicsState()
}

let src = bitmap(big)
let pad = Double(big) / 16
draw(src) { r in NSImage(contentsOfFile: a[1])!.draw(in: r.insetBy(dx: pad, dy: pad)) }
let d = src.bitmapData!
for i in 0..<(big * big) {
    let o = i * 4
    let white = Double(min(d[o], d[o + 1], d[o + 2])) / 255
    let al = max(0, min(1, (white - 0.78) / 0.14)) // ponytail: fixed thresholds tuned for this logo's coral
    d[o] = 0; d[o + 1] = 0; d[o + 2] = 0; d[o + 3] = UInt8(al * 255)
}

let out = bitmap(px)
out.size = NSSize(width: Double(px) * 72 / dpi, height: Double(px) * 72 / dpi)
draw(out) { r in src.draw(in: r) }
try! out.representation(using: .tiff, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
