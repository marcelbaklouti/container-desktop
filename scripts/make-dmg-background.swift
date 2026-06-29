import AppKit

// 2x asset: 1320x800 px shown in a 660x400 pt DMG window (crisp on Retina).
let pxW = 1320, pxH = 800
let ptW = 660.0, ptH = 400.0
let out = CommandLine.arguments[1]

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext
let W = Double(pxW), H = Double(pxH)

// Background: dark vertical gradient, faintly blue.
let space = CGColorSpaceCreateDeviceRGB()
let bg = CGGradient(colorsSpace: space, colors: [
    NSColor(srgbRed: 0.075, green: 0.085, blue: 0.11, alpha: 1).cgColor,
    NSColor(srgbRed: 0.035, green: 0.04, blue: 0.055, alpha: 1).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Soft blue accent glow behind the arrow (app accent color).
let accent = NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1)
let glow = CGGradient(colorsSpace: space, colors: [
    accent.withAlphaComponent(0.18).cgColor,
    accent.withAlphaComponent(0).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 660, y: H - 350), startRadius: 0,
                       endCenter: CGPoint(x: 660, y: H - 350), endRadius: 380, options: [])

// Arrow from the app icon toward the Applications folder (icons centered at px x=330 and x=990, y(top)=350).
let ay = H - 350.0
NSColor(srgbRed: 0.62, green: 0.66, blue: 0.72, alpha: 0.95).setStroke()
let shaft = NSBezierPath()
shaft.lineWidth = 8; shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 540, y: ay))
shaft.line(to: NSPoint(x: 778, y: ay))
shaft.stroke()
let head = NSBezierPath()
head.lineWidth = 8; head.lineCapStyle = .round; head.lineJoinStyle = .round
head.move(to: NSPoint(x: 738, y: ay + 30))
head.line(to: NSPoint(x: 786, y: ay))
head.line(to: NSPoint(x: 738, y: ay - 30))
head.stroke()

// Text helper (centered horizontally).
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, white: CGFloat, alpha: CGFloat, topY: Double) {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: white, alpha: alpha),
        .paragraphStyle: para,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let h = str.size().height
    str.draw(in: NSRect(x: 0, y: H - topY - h, width: W, height: h))
}

text("Container Desktop", size: 46, weight: .semibold, white: 1.0, alpha: 1, topY: 96)
text("Drag the app onto the Applications folder to install", size: 27, weight: .medium, white: 1.0, alpha: 0.96, topY: 632)

NSGraphicsContext.restoreGraphicsState()

rep.size = NSSize(width: ptW, height: ptH)   // mark as @2x (144 dpi) for a crisp 660x400 pt window
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)  (\(pxW)x\(pxH) px @2x)")
