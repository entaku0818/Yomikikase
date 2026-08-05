import XCTest
import SwiftUI
@testable import VoiceYourText

// iOS 16+ ImageRenderer を使って App Store スクリーンショットを自動生成するテスト
// 実行後 /tmp/vyt_screenshots/ 以下に PNG が生成される
//   - iPhone 6.7": {lang}_NN_{screen}.png      (1290×2796)
//   - iPad 12.9" : {lang}_NN_{screen}_ipad.png (2048×2732)
//
// 描画は Features/Debug/ScreenshotViewV2.swift の `Shot(s:index:isPad:)` に委譲する。
// レイアウト・文言はすべて向こう側（ShotStrings）が持つので、**このファイルに
// キャプションや画面構成を書かないこと**。ここは「書き出し」だけを担う。
//
// v2 の6画面構成（index 0〜5）:
//   01 ホーム / 02 PDF / 03 ハイライト / 04 言語 / 05 音声設定 / 06 マイファイル
//
// 旧 v1（4画面, ScreenshotView.swift）から v2 へ差し替えた理由:
//   - 端末内コンテンツが全ロケール日本語ハードコードだった → ShotStrings で完全ローカライズ
//   - 実機と構成が違い（タブバー無し・322pt レイアウト）フォントが相対的に巨大だった
//     → 実機と同じ 3タブ・430pt(iPhone)/1024pt(iPad) で組んで縮小して貼る
//   - PDF 本文やマイファイル一覧が空でリアリティに欠けていた

@available(iOS 16.0, *)
final class ScreenshotGeneratorTests: XCTestCase {

    private var outputDir: URL {
        URL(fileURLWithPath: "/tmp/vyt_screenshots")
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    // MARK: - 書き出す対象

    /// ファイル名に使う画面名。index の順序と 1:1 で対応させる。
    private static let screenNames = ["home", "pdf", "highlight", "languages", "voice", "myfiles"]

    /// (ファイル名プレフィックスの言語コード, 文言, `\.locale` に渡す識別子)
    private static let locales: [(String, ShotStrings, String)] = [
        ("ja", .ja, "ja"),
        ("en", .en, "en"),
        ("de", .de, "de"),
        ("es", .es, "es"),
        ("fr", .fr, "fr"),
        ("it", .it, "it"),
        ("ko", .ko, "ko"),
        ("th", .th, "th"),
        ("tr", .tr, "tr"),
        ("vi", .vi, "vi"),
    ]

    // MARK: - iPhone 6.7" 生成（430×932 @3.0 = 1290×2796）
    // scale は 3.0 固定。App Store の 6.7" 受付サイズは 1290×2796 のみで、
    // これ以外（過去に 1.609 → 692×1500 で出していた）は deliver の検証で
    // 「Invalid screen size」となり、ロケール単位ではなく upload 全体がキャンセルされる。
    @MainActor
    func testGenerateAllScreenshots() throws {
        try render(isPad: false, size: CGSize(width: 430, height: 932), scale: 3.0, suffix: "")
    }

    // MARK: - iPad 12.9" 生成（512×683 @4.0 = 2048×2732）
    @MainActor
    func testGenerateAllIPadScreenshots() throws {
        try render(isPad: true, size: CGSize(width: 512, height: 683), scale: 4.0, suffix: "_ipad")
    }

    // MARK: - 共通レンダラ
    @MainActor
    private func render(isPad: Bool, size: CGSize, scale: CGFloat, suffix: String) throws {
        var errors: [String] = []
        var written = 0

        for (lang, strings, localeID) in Self.locales {
            for index in Self.screenNames.indices {
                let name = "\(lang)_\(String(format: "%02d", index + 1))_\(Self.screenNames[index])\(suffix)"
                let view = Shot(s: strings, index: index, isPad: isPad)
                    .environment(\.locale, .init(identifier: localeID))
                    .frame(width: size.width, height: size.height)

                let renderer = ImageRenderer(content: view)
                renderer.scale = scale
                guard let uiImage = renderer.uiImage, let data = opaquePNGData(uiImage) else {
                    errors.append("Failed to render: \(name)")
                    continue
                }
                do {
                    try data.write(to: outputDir.appendingPathComponent("\(name).png"))
                    written += 1
                } catch {
                    errors.append("Failed to write \(name): \(error)")
                }
            }
        }

        if !errors.isEmpty { XCTFail("Errors: \(errors.joined(separator: "\n"))") }
        XCTAssertEqual(written, Self.locales.count * Self.screenNames.count,
                       "書き出し枚数が想定と違う（suffix='\(suffix)'）")
        assertPixelSize(suffix: suffix,
                        expected: CGSize(width: size.width * scale, height: size.height * scale))
        assertNoAlphaChannel(suffix: suffix)
        print("✅ Generated \(written) screenshots (suffix='\(suffix)') → \(outputDir.path)")
    }

    // MARK: - アルファチャンネルなしの PNG データ化
    // App Store Connect はスクリーンショットに透過を許さず、透過付きで上げると
    // assetDeliveryState=FAILED / IMAGE_ALPHA_NOT_ALLOWED になる。fastlane 側は
    // アップロード自体は成功扱いで進むため、失敗は ASC のアセット状態を見るまで気づけない。
    // ImageRenderer.uiImage.pngData() は RGBA(color type 6) を出すので、
    // 不透明コンテキストへ描き直してから PNG エンコードする。
    private func opaquePNGData(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
        context.draw(cgImage, in: rect)
        guard let flattened = context.makeImage() else { return nil }
        return UIImage(cgImage: flattened).pngData()
    }

    // MARK: - 生成物の検証
    // PNG の IHDR を直接読む。サイズと color type はどちらも「ASC に上げるまで
    // 露見しない」不具合になり得るので、生成時点で落とす。

    private func generatedFiles(suffix: String) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "png" }
            .filter { suffix.isEmpty ? !$0.lastPathComponent.contains("_ipad") : $0.lastPathComponent.contains("_ipad") }
    }

    /// PNG: 8byte signature + 4byte length + "IHDR" + width(4) + height(4) + bitDepth(1) + colorType(1)
    private func readIHDR(_ url: URL) -> (width: Int, height: Int, colorType: UInt8)? {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let header = try? handle.read(upToCount: 26), header.count == 26 else { return nil }
        try? handle.close()
        func be32(_ offset: Int) -> Int {
            (0..<4).reduce(0) { ($0 << 8) | Int(header[offset + $1]) }
        }
        return (be32(16), be32(20), header[25])
    }

    private func assertPixelSize(suffix: String, expected: CGSize) {
        let targets = generatedFiles(suffix: suffix)
        XCTAssertFalse(targets.isEmpty, "No PNG generated for suffix='\(suffix)'")
        for url in targets {
            guard let ihdr = readIHDR(url) else {
                XCTFail("Cannot read PNG header: \(url.lastPathComponent)")
                continue
            }
            XCTAssertEqual(CGSize(width: ihdr.width, height: ihdr.height), expected,
                           "\(url.lastPathComponent): サイズが App Store の受付値と違う")
        }
    }

    private func assertNoAlphaChannel(suffix: String) {
        for url in generatedFiles(suffix: suffix) {
            guard let ihdr = readIHDR(url) else { continue }
            XCTAssertTrue(ihdr.colorType == 0 || ihdr.colorType == 2,
                          "\(url.lastPathComponent): PNG color type \(ihdr.colorType) にアルファが含まれる（ASC は IMAGE_ALPHA_NOT_ALLOWED で弾く）")
        }
    }
}
