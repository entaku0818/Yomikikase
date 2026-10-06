// ocr_region.swift
// 画像の1行を Vision で読み、行の文字列と、横方向 hx0〜hx1 にかかる部分（読み上げ中のハイライト）を出す。
// compose_screenshots.py の拡大カード用。
// 使い方: xcrun swift ocr_region.swift <image> <x> <y> <w> <h> <hx0> <hx1> <ja|en>
// 出力: 1行目=行の文字列、2行目=ハイライト部分の文字列

import AppKit
import Vision

let args = CommandLine.arguments
guard args.count == 9,
      let image = NSImage(contentsOfFile: args[1]),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let x = Int(args[2]), let y = Int(args[3]), let w = Int(args[4]), let h = Int(args[5]),
      let hx0 = Double(args[6]), let hx1 = Double(args[7]),
      let cropped = cgImage.cropping(to: CGRect(x: x, y: y, width: w, height: h)) else {
    FileHandle.standardError.write("usage: ocr_region.swift <image> <x> <y> <w> <h> <hx0> <hx1> <ja|en>\n".data(using: .utf8)!)
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = args[8] == "ja" ? ["ja-JP", "en-US"] : ["en-US"]
request.usesLanguageCorrection = args[8] != "ja"
try VNImageRequestHandler(cgImage: cropped).perform([request])

var line = ""
var highlighted = ""
for observation in request.results ?? [] {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let string = candidate.string
    line += string
    for index in string.indices {
        let range = index..<string.index(after: index)
        guard let box = try? candidate.boundingBox(for: range)?.boundingBox else { continue }
        // 正規化座標 → 元画像の x 座標（文字の中心）
        let center = Double(x) + Double(box.midX) * Double(w)
        if center >= hx0 && center <= hx1 {
            highlighted += String(string[range])
        }
    }
}
print(line)
print(highlighted)
