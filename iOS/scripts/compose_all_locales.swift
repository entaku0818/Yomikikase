import AppKit
import Foundation

// Render localized marketing captions using Core Text font fallback, including RTL and Indic scripts.
// The app screen itself is a real simulator capture; its contents are never replaced.
let arguments = CommandLine.arguments
if arguments.count != 4 {
    fputs("Usage: swift compose_all_locales.swift <captions.json> <raw-device-directory> <output-directory>\n", stderr)
    exit(1)
}
let captionsURL = URL(fileURLWithPath: arguments[1])
let rawRoot = URL(fileURLWithPath: arguments[2])
let outputRoot = URL(fileURLWithPath: arguments[3])
let captions = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: captionsURL))
let names = ["home", "myfiles", "settings"]

func drawText(_ text: String, rect: CGRect, initialSize: CGFloat, color: NSColor, weight: NSFont.Weight, rtl: Bool) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byWordWrapping
    style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    var size = initialSize
    var string = NSAttributedString(string: "")
    var bounds = CGRect.zero
    repeat {
        string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style
        ])
        bounds = string.boundingRect(with: CGSize(width: rect.width, height: 10000), options: [.usesLineFragmentOrigin, .usesFontLeading])
        if bounds.height <= rect.height && bounds.width <= rect.width + 1 { break }
        size -= 2
    } while size >= 32
    precondition(bounds.height <= rect.height + 1, "Caption overflow: \(text)")
    let target = CGRect(x: rect.minX, y: rect.midY - bounds.height / 2, width: rect.width, height: ceil(bounds.height))
    string.draw(with: target, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

var written = 0
for (locale, strings) in captions.sorted(by: { $0.key < $1.key }) {
    let input = rawRoot.appendingPathComponent(locale)
    guard FileManager.default.fileExists(atPath: input.path) else { continue }
    let files = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    let output = outputRoot.appendingPathComponent(locale)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for file in files {
        guard let index = Int(file.lastPathComponent.prefix(1)), names.indices.contains(index),
              let image = NSImage(contentsOf: file),
              let representation = image.representations.first else { fatalError("Invalid screen: \(file.path)") }
        let w = representation.pixelsWide, h = representation.pixelsHigh
        let width = CGFloat(w), height = CGFloat(h)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Bitmap allocation failed") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSGradient(starting: NSColor(srgbRed: 75/255, green: 71/255, blue: 224/255, alpha: 1), ending: NSColor(srgbRed: 52/255, green: 48/255, blue: 170/255, alpha: 1))!.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)
        let rtl = ["ar-SA", "he", "ur-PK"].contains(locale)
        // iPad's system status bar follows the simulator OS language, not the app locale.
        // Crop that OS-only strip; preserve the actual app content and its aspect ratio.
        let contentHeight = height - (w > 1500 ? 50 : 0)
        let scale = min((height - 600) / contentHeight, (width - 140) / width)
        let frame = CGRect(x: (width - width * scale) / 2, y: 65, width: width * scale, height: contentHeight * scale)
        NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1).setFill()
        NSBezierPath(roundedRect: frame.insetBy(dx: -14, dy: -14), xRadius: 54, yRadius: 54).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: frame, xRadius: 40, yRadius: 40).addClip()
        image.draw(in: frame, from: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height * contentHeight / height), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let title = strings["shot.\(names[index]).title"]!
        let subtitle = strings["shot.\(names[index]).subtitle"]!
        drawText(title, rect: CGRect(x: 75, y: height - 325, width: width - 150, height: 250), initialSize: w > 1500 ? 116 : 108, color: .white, weight: .bold, rtl: rtl)
        drawText(subtitle, rect: CGRect(x: 85, y: height - 465, width: width - 170, height: 120), initialSize: w > 1500 ? 65 : 54, color: NSColor(srgbRed: 0.85, green: 0.84, blue: 1, alpha: 1), weight: .medium, rtl: rtl)
        NSGraphicsContext.restoreGraphicsState()
        let rgb = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 3, bitsPerPixel: 24)!
        let source = bitmap.bitmapData!, destination = rgb.bitmapData!
        for y in 0..<h { for x in 0..<w {
            let a = y * bitmap.bytesPerRow + x * 4, b = y * rgb.bytesPerRow + x * 3
            destination[b] = source[a]; destination[b + 1] = source[a + 1]; destination[b + 2] = source[a + 2]
        } }
        guard let png = rgb.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
        try png.write(to: output.appendingPathComponent(file.lastPathComponent))
        written += 1
    }
}
print("Composed \(written) screenshots → \(outputRoot.path)")
