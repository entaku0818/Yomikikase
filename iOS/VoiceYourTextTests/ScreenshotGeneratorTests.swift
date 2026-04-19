import XCTest
import SwiftUI
@testable import VoiceYourText

// iOS 16+ ImageRenderer を使って App Store スクリーンショットを自動生成するテスト
// 実行後 /tmp/vyt_screenshots/ 以下に PNG が生成される

@available(iOS 16.0, *)
final class ScreenshotGeneratorTests: XCTestCase {

    // 430×932 pt × scale=1.609 ≈ 692×1500 px (既存サイズに合わせる)
    private let size = CGSize(width: 430, height: 932)
    private let scale: CGFloat = 1.609

    private var outputDir: URL {
        URL(fileURLWithPath: "/tmp/vyt_screenshots")
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    // MARK: - 全 40 枚生成

    @MainActor
    func testGenerateAllScreenshots() throws {
        let screenshots = allScreenshots()
        var errors: [String] = []

        for (filename, view) in screenshots {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.scale = scale
            guard let uiImage = renderer.uiImage,
                  let data = uiImage.pngData() else {
                errors.append("Failed to render: \(filename)")
                continue
            }
            let url = outputDir.appendingPathComponent("\(filename).png")
            do {
                try data.write(to: url)
            } catch {
                errors.append("Failed to write \(filename): \(error)")
            }
        }

        if !errors.isEmpty {
            XCTFail("Errors: \(errors.joined(separator: "\n"))")
        }

        let generated = (try? FileManager.default.contentsOfDirectory(atPath: outputDir.path))?.count ?? 0
        print("✅ Generated \(generated) screenshots → \(outputDir.path)")
    }

    // MARK: - Screenshot definitions

    @MainActor
    private func allScreenshots() -> [(String, AnyView)] {
        [
            // JA
            ("ja_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "読む手間を、\n声に任せよう")       { PDFReadingContent() }.environment(\.locale, .init(identifier: "ja")))),
            ("ja_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF・Web・\n電子書籍に対応")        { MockScreenWithTopTab(title: "読み上げ")          { HomeContent() } }.environment(\.locale, .init(identifier: "ja")))),
            ("ja_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "リアルタイム\nハイライトで聴きやすい") { HighlightReadingContent() }.environment(\.locale, .init(identifier: "ja")))),
            ("ja_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "保存して、\nいつでも続きから")       { MockScreenWithTopTab(title: "マイファイル")      { MyFilesContent() } }.environment(\.locale, .init(identifier: "ja")))),
            // EN
            ("en_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Let Your Voice\nDo the Reading")       { PDFReadingContent() }.environment(\.locale, .init(identifier: "en")))),
            ("en_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, Web &\neBooks Supported")         { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "en")))),
            ("en_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Follow Along\nwith Highlights")        { HighlightReadingContent() }.environment(\.locale, .init(identifier: "en")))),
            ("en_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Save &\nContinue Anytime")             { MockScreenWithTopTab(title: "My Files")        { MyFilesContent() } }.environment(\.locale, .init(identifier: "en")))),
            // DE
            ("de_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Lesen leicht\ngemacht")                { PDFReadingContent() }.environment(\.locale, .init(identifier: "de")))),
            ("de_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, Web und\neBooks unterstützt")     { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "de")))),
            ("de_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Echtzeit-\nHervorhebung")              { HighlightReadingContent() }.environment(\.locale, .init(identifier: "de")))),
            ("de_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Speichern &\nJederzeit weiterlesen")   { MockScreenWithTopTab(title: "Meine Dateien")   { MyFilesContent() } }.environment(\.locale, .init(identifier: "de")))),
            // ES
            ("es_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Deja que la voz\nlea por ti")          { PDFReadingContent() }.environment(\.locale, .init(identifier: "es")))),
            ("es_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, web\ny eBooks")                   { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "es")))),
            ("es_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Subrayado\nen tiempo real")            { HighlightReadingContent() }.environment(\.locale, .init(identifier: "es")))),
            ("es_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Guarda y\ncontinúa siempre")           { MockScreenWithTopTab(title: "Mis archivos")    { MyFilesContent() } }.environment(\.locale, .init(identifier: "es")))),
            // FR
            ("fr_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Laissez la voix\nfaire la lecture")    { PDFReadingContent() }.environment(\.locale, .init(identifier: "fr")))),
            ("fr_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, Web et\ne-books pris en charge")  { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "fr")))),
            ("fr_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Surlignage\nen temps réel")            { HighlightReadingContent() }.environment(\.locale, .init(identifier: "fr")))),
            ("fr_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Enregistrez &\nreprenez à tout moment") { MockScreenWithTopTab(title: "Mes fichiers")   { MyFilesContent() } }.environment(\.locale, .init(identifier: "fr")))),
            // IT
            ("it_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Lascia che la voce\nlegga per te")     { PDFReadingContent() }.environment(\.locale, .init(identifier: "it")))),
            ("it_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, Web ed\ne-book supportati")       { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "it")))),
            ("it_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Evidenziazione\nin tempo reale")       { HighlightReadingContent() }.environment(\.locale, .init(identifier: "it")))),
            ("it_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Salva e\ncontinua sempre")             { MockScreenWithTopTab(title: "I miei file")     { MyFilesContent() } }.environment(\.locale, .init(identifier: "it")))),
            // KO
            ("ko_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "읽는 수고를\n목소리에 맡겨요")           { PDFReadingContent() }.environment(\.locale, .init(identifier: "ko")))),
            ("ko_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF・웹・\n전자책 지원")                  { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "ko")))),
            ("ko_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "실시간 하이라이트로\n듣기 편해요")         { HighlightReadingContent() }.environment(\.locale, .init(identifier: "ko")))),
            ("ko_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "저장하고\n언제든지 이어서")              { MockScreenWithTopTab(title: "내 파일")          { MyFilesContent() } }.environment(\.locale, .init(identifier: "ko")))),
            // TH
            ("th_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "ปล่อยให้เสียง\nอ่านแทนคุณ")           { PDFReadingContent() }.environment(\.locale, .init(identifier: "th")))),
            ("th_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "รองรับ PDF\nเว็บ และ eBook")           { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "th")))),
            ("th_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "ไฮไลต์\nแบบเรียลไทม์")                { HighlightReadingContent() }.environment(\.locale, .init(identifier: "th")))),
            ("th_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "บันทึกแล้ว\nต่อได้ทุกเมื่อ")          { MockScreenWithTopTab(title: "ไฟล์ของฉัน")     { MyFilesContent() } }.environment(\.locale, .init(identifier: "th")))),
            // TR
            ("tr_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Okuma zahmetini\nsese bırakın")        { PDFReadingContent() }.environment(\.locale, .init(identifier: "tr")))),
            ("tr_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "PDF, Web ve\ne-Kitap desteği")         { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "tr")))),
            ("tr_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Gerçek zamanlı\nvurgu")                { HighlightReadingContent() }.environment(\.locale, .init(identifier: "tr")))),
            ("tr_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Kaydet &\nistediğinde devam et")       { MockScreenWithTopTab(title: "Dosyalarım")      { MyFilesContent() } }.environment(\.locale, .init(identifier: "tr")))),
            // VI
            ("vi_01_demo",     AnyView(AppStoreScreenshotWithFrame(caption: "Để giọng nói\nđọc cho bạn")           { PDFReadingContent() }.environment(\.locale, .init(identifier: "vi")))),
            ("vi_02_features", AnyView(AppStoreScreenshotWithFrame(caption: "Hỗ trợ PDF\nWeb & eBook")              { MockScreenWithTopTab(title: "Voice Narrator")  { HomeContent() } }.environment(\.locale, .init(identifier: "vi")))),
            ("vi_03_highlight",AnyView(AppStoreScreenshotWithFrame(caption: "Tô sáng\ntheo thời gian thực")        { HighlightReadingContent() }.environment(\.locale, .init(identifier: "vi")))),
            ("vi_04_myfiles",  AnyView(AppStoreScreenshotWithFrame(caption: "Lưu &\ntiếp tục bất cứ lúc nào")     { MockScreenWithTopTab(title: "Tệp của tôi")     { MyFilesContent() } }.environment(\.locale, .init(identifier: "vi")))),
        ]
    }
}
