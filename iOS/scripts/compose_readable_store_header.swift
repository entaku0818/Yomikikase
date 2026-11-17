import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Recompose the existing captured UI and brand style at a readable headline size.
// Coordinates below use the top-left origin from Apple's header template.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 3840, height = 1646
let safe = CGRect(x: 1097, y: 493, width: 1646, height: 661)
let titles = ["ja": "文章を、\n耳で読む。", "en-US": "Text to\nspeech."]
var measurements: [[String: Any]] = []

func bottomRect(_ top: CGRect) -> CGRect {
    CGRect(x: top.minX, y: CGFloat(height) - top.maxY, width: top.width, height: top.height)
}

for locale in titles.keys.sorted() {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGradient(starting: NSColor(srgbRed: 75/255, green: 71/255, blue: 224/255, alpha: 1),
               ending: NSColor(srgbRed: 52/255, green: 48/255, blue: 170/255, alpha: 1))!
        .draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)
    // Preserve the established background; no essential content lives outside safe.
    for index in 0..<18 {
        let x = CGFloat(index) * 240 - 160
        NSColor(white: 1, alpha: 0.045).setStroke()
        let wave = NSBezierPath()
        wave.lineWidth = 10
        wave.move(to: CGPoint(x: x, y: 0))
        wave.curve(to: CGPoint(x: x + 1200, y: CGFloat(height)),
                   controlPoint1: CGPoint(x: x + 1500, y: CGFloat(height) * 0.3),
                   controlPoint2: CGPoint(x: x - 350, y: CGFloat(height) * 0.7))
        wave.stroke()
    }

    let titleBox = CGRect(x: 1129, y: 535, width: 1120, height: 580)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 4
    let fontSize: CGFloat = 220
    let title = NSAttributedString(string: titles[locale]!, attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.white, .paragraphStyle: paragraph
    ])
    let bounds = title.boundingRect(with: CGSize(width: titleBox.width, height: 1000),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading])
    precondition(bounds.width <= titleBox.width && bounds.height <= titleBox.height)
    let titleDraw = CGRect(x: titleBox.minX, y: titleBox.midY - bounds.height / 2,
                           width: titleBox.width, height: ceil(bounds.height))
    precondition(safe.contains(titleDraw))
    title.draw(with: bottomRect(titleDraw), options: [.usesLineFragmentOrigin, .usesFontLeading])

    let sourceURL = root.appendingPathComponent("source/\(locale)-playing.png")
    let image = NSImage(contentsOf: sourceURL)!
    let detail = NSImage(contentsOf: root.appendingPathComponent("source/\(locale)-highlight.png"))!
    let info = try JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("source/\(locale)-highlight.json"))) as! [String: Any]
    let phoneTop = CGRect(x: 2380, y: 510, width: 288, height: 288 * image.size.height / image.size.width)
    precondition(safe.contains(phoneTop.insetBy(dx: -12, dy: -12)))
    let phone = bottomRect(phoneTop)
    NSColor(srgbRed: 0.06, green: 0.06, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(roundedRect: phone.insetBy(dx: -12, dy: -12), xRadius: 44, yRadius: 44).fill()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: phone, xRadius: 34, yRadius: 34).addClip()
    image.draw(in: phone, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let factor = phone.width / 440
    NSColor.black.setFill()
    let island = CGRect(x: phone.midX - 63 * factor, y: phone.maxY - 48 * factor,
                        width: 126 * factor, height: 37 * factor)
    NSBezierPath(roundedRect: island, xRadius: 18.5 * factor, yRadius: 18.5 * factor).fill()
    let detailWidth: CGFloat = 392
    let detailHeight = detail.size.height * detailWidth / detail.size.width
    let center = phoneTop.minY + (info["centerY"] as! Double) * phoneTop.height
    let detailTop = CGRect(x: phoneTop.midX - detailWidth / 2, y: center - detailHeight / 2,
                           width: detailWidth, height: detailHeight)
    precondition(safe.contains(detailTop.insetBy(dx: -12, dy: -12)))
    NSColor.white.setFill()
    NSBezierPath(roundedRect: bottomRect(detailTop).insetBy(dx: -12, dy: -12), xRadius: 16, yRadius: 16).fill()
    detail.draw(in: bottomRect(detailTop))
    NSGraphicsContext.restoreGraphicsState()

    let output = root.appendingPathComponent("after/\(locale).png")
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rgb = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    rgb.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
    let encoder = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(encoder, rgb.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(encoder))
    measurements.append(["locale": locale, "headline": titles[locale]!, "headlineFontPixels": fontSize,
                         "headlineAt390Width": fontSize * 390 / CGFloat(width), "safeAreaPass": true,
                         "phonePixelsPreserved": true, "status": "LOCAL_PROPOSAL_NOT_UPLOADED"])
}
try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("layout-validation.json"))
