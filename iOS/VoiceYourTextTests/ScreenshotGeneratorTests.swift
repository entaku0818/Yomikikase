import XCTest
import SwiftUI
@testable import VoiceYourText

// iOS 16+ ImageRenderer を使って App Store スクリーンショットを自動生成するテスト
// 実行後 /tmp/vyt_screenshots/ 以下に PNG が生成される
//   - iPhone 6.7": {lang}_NN_*.png      (692×1500)
//   - iPad 12.9" : {lang}_NN_*_ipad.png (2048×2732)
// 刷新案デザイン（インディゴ統一）の4画面構成・全枚共通:
//   01 = ホーム（インポート元グリッド + 最近のファイル）
//   02 = マルチ対応（PDF読み上げ）
//   03 = ハイライト（読み上げ中の文を追従表示）
//   04 = 続きから（マイファイル: 検索・フィルタ・進捗）

@available(iOS 16.0, *)
final class ScreenshotGeneratorTests: XCTestCase {

    private var outputDir: URL {
        URL(fileURLWithPath: "/tmp/vyt_screenshots")
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    // MARK: - 1画面の仕様
    private struct Spec {
        let name: String        // ファイル名プレフィックス（例: ja_01_home）
        let locale: String
        let caption: String
        let subtitle: String?
        let content: AnyView    // iPhone/iPad で共通のアプリ画面（フレームなし）
    }

    // MARK: - iPhone 6.7" 生成（430×932 @1.609 ≈ 692×1500）
    @MainActor
    func testGenerateAllScreenshots() throws {
        try render(
            wrap: { spec in
                AnyView(
                    AppStoreScreenshotWithFrame(caption: spec.caption, subtitle: spec.subtitle) { spec.content }
                        .environment(\.locale, .init(identifier: spec.locale))
                )
            },
            size: CGSize(width: 430, height: 932),
            scale: 1.609,
            suffix: ""
        )
    }

    // MARK: - iPad 12.9" 生成（512×683 @4.0 = 2048×2732）
    @MainActor
    func testGenerateAllIPadScreenshots() throws {
        try render(
            wrap: { spec in
                AnyView(
                    iPadScreenshotWithFrame(caption: spec.caption, subtitle: spec.subtitle) { spec.content }
                        .environment(\.locale, .init(identifier: spec.locale))
                )
            },
            size: CGSize(width: 512, height: 683),
            scale: 4.0,
            suffix: "_ipad"
        )
    }

    // MARK: - 共通レンダラ
    @MainActor
    private func render(wrap: (Spec) -> AnyView, size: CGSize, scale: CGFloat, suffix: String) throws {
        var errors: [String] = []
        for spec in specs() {
            let view = wrap(spec).frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
                errors.append("Failed to render: \(spec.name)\(suffix)")
                continue
            }
            let url = outputDir.appendingPathComponent("\(spec.name)\(suffix).png")
            do { try data.write(to: url) } catch { errors.append("Failed to write \(spec.name)\(suffix): \(error)") }
        }
        if !errors.isEmpty { XCTFail("Errors: \(errors.joined(separator: "\n"))") }
        let generated = (try? FileManager.default.contentsOfDirectory(atPath: outputDir.path))?.count ?? 0
        print("✅ Generated screenshots (suffix='\(suffix)') → total now \(generated) files in \(outputDir.path)")
    }

    // MARK: - 全画面定義（iPhone/iPad 共通）
    @MainActor
    private func specs() -> [Spec] {
        func home(_ title: String) -> AnyView { AnyView(MockScreenWithTopTab(title: title) { HomeContent() }) }
        func myfiles(_ title: String) -> AnyView { AnyView(MockScreenWithTopTab(title: title) { MyFilesContent() }) }
        let multi = { AnyView(PDFReadingContent()) }
        let highlight = { AnyView(HighlightReadingContent()) }

        return [
            // JA
            Spec(name: "ja_01_home",      locale: "ja", caption: "読む手間を、\n声に。",        subtitle: "テキスト・PDF・本・Web・スキャン",      content: home("ナレーター")),
            Spec(name: "ja_02_multi",     locale: "ja", caption: "PDFも、本も、\nWebも。",      subtitle: "どんな文章も、そのまま読み上げ",        content: multi()),
            Spec(name: "ja_03_highlight", locale: "ja", caption: "今読んでいる文を、\nハイライト", subtitle: "目と耳で、もっと聴きやすい",            content: highlight()),
            Spec(name: "ja_04_myfiles",   locale: "ja", caption: "保存して、\nいつでも続きから",   subtitle: "進捗も、声の設定も記憶",              content: myfiles("マイファイル")),
            // EN
            Spec(name: "en_01_home",      locale: "en", caption: "Let your voice\ndo the reading",    subtitle: "Text, PDF, books, web & scans",       content: home("Narrator")),
            Spec(name: "en_02_multi",     locale: "en", caption: "PDF, books &\nthe web — all read",  subtitle: "Any text, read aloud as is",          content: multi()),
            Spec(name: "en_03_highlight", locale: "en", caption: "Highlights the\nline being read",   subtitle: "Easier to follow by eye and ear",     content: highlight()),
            Spec(name: "en_04_myfiles",   locale: "en", caption: "Save & pick up\nwhere you left off", subtitle: "Remembers progress & voice settings", content: myfiles("My Files")),
            // DE
            Spec(name: "de_01_home",      locale: "de", caption: "Lesen leicht\ngemacht",               subtitle: nil, content: home("Narrator")),
            Spec(name: "de_02_multi",     locale: "de", caption: "PDF, Web und\neBooks unterstützt",    subtitle: nil, content: multi()),
            Spec(name: "de_03_highlight", locale: "de", caption: "Echtzeit-\nHervorhebung",             subtitle: nil, content: highlight()),
            Spec(name: "de_04_myfiles",   locale: "de", caption: "Speichern &\nJederzeit weiterlesen",  subtitle: nil, content: myfiles("Meine Dateien")),
            // ES
            Spec(name: "es_01_home",      locale: "es", caption: "Deja que la voz\nlea por ti",  subtitle: nil, content: home("Narrator")),
            Spec(name: "es_02_multi",     locale: "es", caption: "PDF, web\ny eBooks",           subtitle: nil, content: multi()),
            Spec(name: "es_03_highlight", locale: "es", caption: "Subrayado\nen tiempo real",    subtitle: nil, content: highlight()),
            Spec(name: "es_04_myfiles",   locale: "es", caption: "Guarda y\ncontinúa siempre",   subtitle: nil, content: myfiles("Mis archivos")),
            // FR
            Spec(name: "fr_01_home",      locale: "fr", caption: "Laissez la voix\nfaire la lecture",   subtitle: nil, content: home("Narrator")),
            Spec(name: "fr_02_multi",     locale: "fr", caption: "PDF, Web et\ne-books pris en charge", subtitle: nil, content: multi()),
            Spec(name: "fr_03_highlight", locale: "fr", caption: "Surlignage\nen temps réel",           subtitle: nil, content: highlight()),
            Spec(name: "fr_04_myfiles",   locale: "fr", caption: "Enregistrez &\nreprenez à tout moment", subtitle: nil, content: myfiles("Mes fichiers")),
            // IT
            Spec(name: "it_01_home",      locale: "it", caption: "Lascia che la voce\nlegga per te", subtitle: nil, content: home("Narrator")),
            Spec(name: "it_02_multi",     locale: "it", caption: "PDF, Web ed\ne-book supportati",   subtitle: nil, content: multi()),
            Spec(name: "it_03_highlight", locale: "it", caption: "Evidenziazione\nin tempo reale",   subtitle: nil, content: highlight()),
            Spec(name: "it_04_myfiles",   locale: "it", caption: "Salva e\ncontinua sempre",         subtitle: nil, content: myfiles("I miei file")),
            // KO
            Spec(name: "ko_01_home",      locale: "ko", caption: "읽는 수고를\n목소리에 맡겨요",   subtitle: nil, content: home("Narrator")),
            Spec(name: "ko_02_multi",     locale: "ko", caption: "PDF・웹・\n전자책 지원",          subtitle: nil, content: multi()),
            Spec(name: "ko_03_highlight", locale: "ko", caption: "실시간 하이라이트로\n듣기 편해요", subtitle: nil, content: highlight()),
            Spec(name: "ko_04_myfiles",   locale: "ko", caption: "저장하고\n언제든지 이어서",       subtitle: nil, content: myfiles("내 파일")),
            // TH
            Spec(name: "th_01_home",      locale: "th", caption: "ปล่อยให้เสียง\nอ่านแทนคุณ",   subtitle: nil, content: home("Narrator")),
            Spec(name: "th_02_multi",     locale: "th", caption: "รองรับ PDF\nเว็บ และ eBook",   subtitle: nil, content: multi()),
            Spec(name: "th_03_highlight", locale: "th", caption: "ไฮไลต์\nแบบเรียลไทม์",        subtitle: nil, content: highlight()),
            Spec(name: "th_04_myfiles",   locale: "th", caption: "บันทึกแล้ว\nต่อได้ทุกเมื่อ",  subtitle: nil, content: myfiles("ไฟล์ของฉัน")),
            // TR
            Spec(name: "tr_01_home",      locale: "tr", caption: "Okuma zahmetini\nsese bırakın",  subtitle: nil, content: home("Narrator")),
            Spec(name: "tr_02_multi",     locale: "tr", caption: "PDF, Web ve\ne-Kitap desteği",   subtitle: nil, content: multi()),
            Spec(name: "tr_03_highlight", locale: "tr", caption: "Gerçek zamanlı\nvurgu",          subtitle: nil, content: highlight()),
            Spec(name: "tr_04_myfiles",   locale: "tr", caption: "Kaydet &\nistediğinde devam et", subtitle: nil, content: myfiles("Dosyalarım")),
            // VI
            Spec(name: "vi_01_home",      locale: "vi", caption: "Để giọng nói\nđọc cho bạn",     subtitle: nil, content: home("Narrator")),
            Spec(name: "vi_02_multi",     locale: "vi", caption: "Hỗ trợ PDF\nWeb & eBook",        subtitle: nil, content: multi()),
            Spec(name: "vi_03_highlight", locale: "vi", caption: "Tô sáng\ntheo thời gian thực",   subtitle: nil, content: highlight()),
            Spec(name: "vi_04_myfiles",   locale: "vi", caption: "Lưu &\ntiếp tục bất cứ lúc nào", subtitle: nil, content: myfiles("Tệp của tôi")),
        ]
    }
}
