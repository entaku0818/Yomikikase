import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Composite actual simulator captures with native text shaping for all 50 locales.
struct Slide: Decodable { let screen: String; let title: String; let subtitle: String }
struct Detail: Decodable { let centerY: CGFloat }
let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Usage: compose captions.json raw-directory output-directory") }
let captions = try JSONDecoder().decode([String: [Slide]].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let raw = URL(fileURLWithPath: args[2]), output = URL(fileURLWithPath: args[3])

func text(_ value: String, in rect: CGRect, maximum: CGFloat, color: NSColor, bold: Bool, rtl: Bool) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 8
    var size = maximum
    var string: NSAttributedString
    var bounds: CGRect
    repeat {
        string = NSAttributedString(string: value, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: bold ? .bold : .medium),
            .foregroundColor: color, .paragraphStyle: paragraph
        ])
        bounds = string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading])
        if bounds.height <= rect.height { break }
        size -= 2
    } while size >= 30
    precondition(bounds.height <= rect.height + 1, "Caption overflow: \(value)")
    string.draw(with: CGRect(x: rect.minX, y: rect.midY - bounds.height / 2,
                             width: rect.width, height: ceil(bounds.height)),
                options: [.usesLineFragmentOrigin, .usesFontLeading])
}

var count = 0
for device in ["iphone", "ipad"] {
    for (locale, slides) in captions.sorted(by: { $0.key < $1.key }) {
        let input = raw.appendingPathComponent(device).appendingPathComponent(locale)
        guard slides.allSatisfy({ FileManager.default.fileExists(atPath: input.appendingPathComponent($0.screen + ".png").path) }) else { continue }
        let destination = output.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for (index, slide) in slides.enumerated() {
            let file = input.appendingPathComponent(slide.screen + ".png")
            guard let image = NSImage(contentsOf: file), let source = image.representations.first else { fatalError(file.path) }
            let isPad = device == "ipad"
            let w = isPad ? 2048 : 1320, h = isPad ? 2732 : 2868
            let width = CGFloat(w), height = CGFloat(h)
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32),
                  let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Bitmap allocation failed") }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            NSGradient(starting: NSColor(srgbRed: 75/255, green: 71/255, blue: 224/255, alpha: 1),
                       ending: NSColor(srgbRed: 52/255, green: 48/255, blue: 170/255, alpha: 1))!
                .draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)
            let rtl = ["ar-SA", "he", "ur-PK"].contains(locale)
            text(slide.title, in: CGRect(x: 80, y: height - 495, width: width - 160, height: 330),
                 maximum: isPad ? 158 : 126, color: .white, bold: true, rtl: rtl)
            text(slide.subtitle, in: CGRect(x: 85, y: height - 625, width: width - 170, height: 105),
                 maximum: isPad ? 62 : 48, color: NSColor(srgbRed: 0.85, green: 0.84, blue: 1, alpha: 1), bold: false, rtl: rtl)

            let sourceWidth = CGFloat(source.pixelsWide), sourceHeight = CGFloat(source.pixelsHigh)
            let contentHeight = sourceHeight - (isPad ? 50 : 0)
            let scale = min((height - 825) / contentHeight, (width - 180) / sourceWidth)
            let frame = CGRect(x: (width - sourceWidth * scale) / 2, y: 75,
                               width: sourceWidth * scale, height: contentHeight * scale)
            NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1).setFill()
            let radius: CGFloat = isPad ? 58 : 132
            NSBezierPath(roundedRect: frame.insetBy(dx: -24, dy: -24), xRadius: radius + 20, yRadius: radius + 20).fill()
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
            image.draw(in: frame, from: CGRect(x: 0, y: 0, width: image.size.width,
                       height: image.size.height * contentHeight / sourceHeight), operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            if !isPad {
                let factor = frame.width / 440
                let island = CGRect(x: frame.midX - 63 * factor, y: frame.maxY - 48 * factor,
                                    width: 126 * factor, height: 37 * factor)
                NSColor.black.setFill()
                NSBezierPath(roundedRect: island, xRadius: 18.5 * factor, yRadius: 18.5 * factor).fill()
            }
            if slide.screen == "playing" {
                let detailRoot = raw.deletingLastPathComponent().appendingPathComponent("details")
                    .appendingPathComponent(device).appendingPathComponent(locale)
                if let detailImage = NSImage(contentsOf: detailRoot.appendingPathComponent("playing.png")),
                   let data = try? Data(contentsOf: detailRoot.appendingPathComponent("playing.json")),
                   let detail = try? JSONDecoder().decode(Detail.self, from: data) {
                    let cardWidth = width - 100
                    let contentWidth = cardWidth - 40
                    let contentHeight = detailImage.size.height * contentWidth / detailImage.size.width
                    let centerY = frame.maxY - detail.centerY * sourceHeight * scale
                    let card = CGRect(x: 50, y: centerY - contentHeight / 2 - 20,
                                      width: cardWidth, height: contentHeight + 40)
                    NSColor.white.setFill()
                    NSBezierPath(roundedRect: card, xRadius: 30, yRadius: 30).fill()
                    detailImage.draw(in: card.insetBy(dx: 20, dy: 20))
                }
            }
            NSGraphicsContext.restoreGraphicsState()
            guard let cg = bitmap.cgImage,
                  let opaque = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("RGB conversion failed") }
            opaque.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            let name = "\(index)_\(isPad ? "IPAD_PRO_3GEN_129" : "IPHONE_69").png"
            let url = destination.appendingPathComponent(name)
            guard let rendered = opaque.makeImage(),
                  let encoder = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("PNG encoder failed") }
            CGImageDestinationAddImage(encoder, rendered, nil)
            precondition(CGImageDestinationFinalize(encoder))
            count += 1
        }
        print("COMPOSED \(locale) \(device) six screens")
    }
}
print("Generated \(count) opaque screenshots")
