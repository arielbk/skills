// Renders caption overlays and card layers as 1440x900 PNGs with CoreText.
// Homebrew ffmpeg has no drawtext/subtitles filters, so all text in the video comes from here.
//
//   render caption <out.png> <text> [bottom|top]
//       dark rounded pill, lower third (or top, when the lower third holds what the viewer reads)
//   render layer <out.png> bg 0
//       opaque card background
//   render layer <out.png> head|sub <centerY> <text>
//       head = large bold ink line, sub = smaller regular grey line (the two-level card hierarchy)
//   render layer <out.png> brand <centerY> <logo.png|""> <name>
//       logo + wordmark, centred (wordmark only when the logo path is empty)
//
// centerY is top-down pixels. Layers are transparent outside their text so they can fade separately.
// Change the palette and fonts here to match the product.
import AppKit

let W: CGFloat = 1440, H: CGFloat = 900
let BG = NSColor(deviceRed: 0.976, green: 0.976, blue: 0.969, alpha: 1)    // #f9f9f7
let INK = NSColor(deviceRed: 0.067, green: 0.067, blue: 0.067, alpha: 1)   // #111111
let MUTED = NSColor(deviceRed: 0.322, green: 0.322, blue: 0.322, alpha: 1) // #525252
let PILL = NSColor(deviceRed: 0.07, green: 0.08, blue: 0.10, alpha: 0.9)

let args = CommandLine.arguments
func arg(_ i: Int) -> String { args.count > i ? args[i] : "" }
func font(_ name: String, _ size: CGFloat) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
}
func save(_ rep: NSBitmapImageRep, _ path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}
func canvas(_ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

switch arg(1) {
case "caption":
    let a = NSAttributedString(string: arg(3), attributes: [.font: font("HelveticaNeue-Medium", 32),
        .foregroundColor: NSColor(deviceWhite: 1, alpha: 1), .kern: 0.2])
    let sz = a.size()
    let padX: CGFloat = 28, padY: CGFloat = 15
    let bottom: CGFloat = arg(4) == "top" ? H - 40 - (sz.height + 2 * padY) : 56
    let rep = canvas {
        let box = NSRect(x: (W - sz.width) / 2 - padX, y: bottom, width: sz.width + 2 * padX, height: sz.height + 2 * padY)
        PILL.setFill()
        NSBezierPath(roundedRect: box, xRadius: 14, yRadius: 14).fill()
        NSColor(deviceWhite: 1, alpha: 0.16).setStroke()
        let p = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        p.lineWidth = 1; p.stroke()
        a.draw(at: NSPoint(x: box.minX + padX, y: bottom + padY))
    }
    save(rep, arg(2))
case "layer":
    let style = arg(3)
    let cy = H - CGFloat(Double(arg(4)) ?? 0)
    let rep = canvas {
        switch style {
        case "bg":
            BG.setFill()
            NSRect(x: 0, y: 0, width: W, height: H).fill()
        case "head", "sub":
            let head = style == "head"
            let a = NSAttributedString(string: arg(5), attributes: [
                .font: head ? font("HelveticaNeue-Bold", 68) : font("HelveticaNeue", 40),
                .foregroundColor: head ? INK : MUTED, .kern: head ? -0.6 : 0])
            let sz = a.size()
            a.draw(at: NSPoint(x: (W - sz.width) / 2, y: cy - sz.height / 2))
        case "brand":
            let logo = arg(5).isEmpty ? nil : NSImage(contentsOfFile: arg(5))
            let L: CGFloat = logo == nil ? 0 : 80, gap: CGFloat = logo == nil ? 0 : 22
            let a = NSAttributedString(string: arg(6), attributes: [.font: font("HelveticaNeue-Bold", 72),
                .foregroundColor: INK, .kern: -0.8])
            let sz = a.size()
            let x0 = (W - (L + gap + sz.width)) / 2
            logo?.draw(in: NSRect(x: x0, y: cy - L / 2, width: L, height: L))
            a.draw(at: NSPoint(x: x0 + L + gap, y: cy - sz.height / 2 - 3))
        default:
            fatalError("unknown layer style \(style)")
        }
    }
    save(rep, arg(2))
default:
    fatalError("usage: render caption|layer ...")
}
