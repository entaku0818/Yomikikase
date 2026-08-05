import XCTest
import SwiftUI
@testable import VoiceYourText

// iOS 16+ ImageRenderer を使って App Store スクリーンショットを自動生成するテスト
// 実行後 /tmp/vyt_screenshots/ 以下に PNG が生成される
//   - iPhone 6.7": {lang}_NN_*.png      (1290×2796)
//   - iPad 12.9" : {lang}_NN_*_ipad.png (2048×2732)
// 刷新案デザイン（インディゴ統一）の4画面構成・全枚共通:
//   01 = ホーム（インポート元グリッド + 最近のファイル）／訴求: 「読み上げアプリ」であることを検索結果で即判別させる
//   02 = マルチ対応（PDF読み上げ）／訴求: 入れるだけ・変換不要
//   03 = ハイライト（読み上げ中の文を追従表示）／訴求: 読んでいる場所が分かる
//   04 = 音声設定（速度・高さ・声）／訴求: アカウント登録不要・オフライン動作・端末内生成
//        ※ 04 は 2026-08-03 の競合調査（#125）でマイファイル「続きから」から差し替え。
//           競合(Speechify ¥22,000/年・Voicepaper AI)は全てクラウド前提のため、
//           端末内生成が最も言うべき差分と判断。
//        ※ コピーで書かないこと（実装と乖離するため）:
//           - 「AI音声」: kokoroEnabled のデフォルトは false なので、既定の音声は
//             AVSpeechSynthesizer。Kokoro は設定でONにしてモデルDLした人のみ
//           - 「端末内だけ」: クラウドTTS（Cloud Run）へ切り替えるオプションがある
//           - 「広告なし」: AdMob を表示しており、広告非表示はプレミアム限定
//           - 価格の数字: 国別に異なるため画像には入れない

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

    // MARK: - iPhone 6.7" 生成（430×932 @3.0 = 1290×2796）
    // scale は 3.0 固定。App Store の 6.7" 受付サイズは 1290×2796 のみで、
    // これ以外（過去に 1.609 → 692×1500 で出していた）は deliver の検証で
    // 「Invalid screen size」となり全ロケール分のアップロードが丸ごとキャンセルされる。
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
            scale: 3.0,
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
            guard let uiImage = renderer.uiImage, let data = opaquePNGData(uiImage) else {
                errors.append("Failed to render: \(spec.name)\(suffix)")
                continue
            }
            let url = outputDir.appendingPathComponent("\(spec.name)\(suffix).png")
            do { try data.write(to: url) } catch { errors.append("Failed to write \(spec.name)\(suffix): \(error)") }
        }
        if !errors.isEmpty { XCTFail("Errors: \(errors.joined(separator: "\n"))") }
        assertNoAlphaChannel(suffix: suffix)
        let generated = (try? FileManager.default.contentsOfDirectory(atPath: outputDir.path))?.count ?? 0
        print("✅ Generated screenshots (suffix='\(suffix)') → total now \(generated) files in \(outputDir.path)")
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

    // 生成物の PNG ヘッダ(IHDR)を直接読み、color type がアルファなし(0/2)であることを検証する。
    // ここで落としておかないと、ASC へ上げるまで透過混入に気づけない。
    private func assertNoAlphaChannel(suffix: String) {
        let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
        let targets = files.filter { $0.pathExtension == "png" }
            .filter { suffix.isEmpty ? !$0.lastPathComponent.contains("_ipad") : $0.lastPathComponent.contains("_ipad") }
        XCTAssertFalse(targets.isEmpty, "No PNG generated for suffix='\(suffix)'")
        for url in targets {
            guard let handle = try? FileHandle(forReadingFrom: url),
                  let header = try? handle.read(upToCount: 26), header.count == 26 else {
                XCTFail("Cannot read PNG header: \(url.lastPathComponent)")
                continue
            }
            try? handle.close()
            // PNG: 8byte signature + 4byte length + "IHDR" + width(4) + height(4) + bitDepth(1) + colorType(1)
            let colorType = header[25]
            XCTAssertTrue(colorType == 0 || colorType == 2,
                          "\(url.lastPathComponent): PNG color type \(colorType) にアルファが含まれる（ASC は IMAGE_ALPHA_NOT_ALLOWED で弾く）")
        }
    }

    // MARK: - 全画面定義（iPhone/iPad 共通）
    @MainActor
    private func specs() -> [Spec] {
        func home(_ title: String) -> AnyView { AnyView(MockScreenWithTopTab(title: title) { HomeContent() }) }
        let multi = { AnyView(PDFReadingContent()) }
        let highlight = { AnyView(HighlightReadingContent()) }
        let voice = { AnyView(SettingsContent()) }

        return [
            // JA
            Spec(name: "ja_01_home",      locale: "ja", caption: "PDFも本も、\nぜんぶ読み上げ",   subtitle: "7つのソースに対応した読み上げアプリ",       content: home("ナレーター")),
            Spec(name: "ja_02_multi",     locale: "ja", caption: "入れるだけで、\nそのまま朗読",   subtitle: "PDF・EPUB・Web。変換もコピペも不要",      content: multi()),
            Spec(name: "ja_03_highlight", locale: "ja", caption: "読んでいる場所が\nひと目でわかる", subtitle: "ハイライト＋自動スクロールで目と耳を同時に",   content: highlight()),
            Spec(name: "ja_04_voice",     locale: "ja", caption: "登録なし、\nオフラインでもOK", subtitle: "音声は端末の中で生成。速度も声も自由に調整",   content: voice()),
            // EN
            Spec(name: "en_01_home",      locale: "en", caption: "Read PDFs, books\n& the web aloud", subtitle: "A text-to-speech app with 7 sources",       content: home("Narrator")),
            Spec(name: "en_02_multi",     locale: "en", caption: "Just drop it in —\nit reads aloud", subtitle: "PDF, EPUB, web. No converting or copy-paste", content: multi()),
            Spec(name: "en_03_highlight", locale: "en", caption: "See exactly where\nit's reading",   subtitle: "Highlight + auto-scroll: follow by eye and ear", content: highlight()),
            Spec(name: "en_04_voice",     locale: "en", caption: "No account,\nworks offline",         subtitle: "Voices made on your device. Tune speed & pitch", content: voice()),
            // DE
            Spec(name: "de_01_home",      locale: "de", caption: "PDFs, Bücher\n& Web vorlesen",     subtitle: nil, content: home("Narrator")),
            Spec(name: "de_02_multi",     locale: "de", caption: "Einfach einfügen —\nes liest vor", subtitle: nil, content: multi()),
            Spec(name: "de_03_highlight", locale: "de", caption: "Immer sehen,\nwo gelesen wird",    subtitle: nil, content: highlight()),
            Spec(name: "de_04_voice",     locale: "de", caption: "Kein Konto,\noffline nutzbar",      subtitle: nil, content: voice()),
            // ES
            Spec(name: "es_01_home",      locale: "es", caption: "Lee en voz alta\nPDF, libros y web", subtitle: nil, content: home("Narrator")),
            Spec(name: "es_02_multi",     locale: "es", caption: "Solo añádelo\ny lo lee",             subtitle: nil, content: multi()),
            Spec(name: "es_03_highlight", locale: "es", caption: "Ve siempre por\ndónde va leyendo",   subtitle: nil, content: highlight()),
            Spec(name: "es_04_voice",     locale: "es", caption: "Sin cuenta,\nfunciona sin conexión", subtitle: nil, content: voice()),
            // FR
            Spec(name: "fr_01_home",      locale: "fr", caption: "Lit à voix haute\nPDF, livres, web", subtitle: nil, content: home("Narrator")),
            Spec(name: "fr_02_multi",     locale: "fr", caption: "Ajoutez-le,\nil le lit",             subtitle: nil, content: multi()),
            Spec(name: "fr_03_highlight", locale: "fr", caption: "Voyez toujours\noù il en est",       subtitle: nil, content: highlight()),
            Spec(name: "fr_04_voice",     locale: "fr", caption: "Sans compte,\nfonctionne hors ligne", subtitle: nil, content: voice()),
            // IT
            Spec(name: "it_01_home",      locale: "it", caption: "Legge ad alta voce\nPDF, libri e web", subtitle: nil, content: home("Narrator")),
            Spec(name: "it_02_multi",     locale: "it", caption: "Aggiungilo\ne lo legge",               subtitle: nil, content: multi()),
            Spec(name: "it_03_highlight", locale: "it", caption: "Vedi sempre\ndove sta leggendo",       subtitle: nil, content: highlight()),
            Spec(name: "it_04_voice",     locale: "it", caption: "Nessun account,\nfunziona offline",      subtitle: nil, content: voice()),
            // KO
            Spec(name: "ko_01_home",      locale: "ko", caption: "PDF·책·웹을\n모두 읽어줘요",     subtitle: nil, content: home("Narrator")),
            Spec(name: "ko_02_multi",     locale: "ko", caption: "넣기만 하면\n그대로 읽어줘요",   subtitle: nil, content: multi()),
            Spec(name: "ko_03_highlight", locale: "ko", caption: "지금 읽는 곳이\n한눈에 보여요",   subtitle: nil, content: highlight()),
            Spec(name: "ko_04_voice",     locale: "ko", caption: "가입 없이,\n오프라인에서도",     subtitle: nil, content: voice()),
            // TH
            Spec(name: "th_01_home",      locale: "th", caption: "อ่านออกเสียง\nPDF หนังสือ เว็บ", subtitle: nil, content: home("Narrator")),
            Spec(name: "th_02_multi",     locale: "th", caption: "แค่ใส่เข้ามา\nก็อ่านให้ฟัง",     subtitle: nil, content: multi()),
            Spec(name: "th_03_highlight", locale: "th", caption: "เห็นชัดว่า\nกำลังอ่านที่ไหน",    subtitle: nil, content: highlight()),
            Spec(name: "th_04_voice",     locale: "th", caption: "ไม่ต้องสมัคร\nใช้ออฟไลน์ได้",     subtitle: nil, content: voice()),
            // TR
            Spec(name: "tr_01_home",      locale: "tr", caption: "PDF, kitap ve web\nsesli okunur",     subtitle: nil, content: home("Narrator")),
            Spec(name: "tr_02_multi",     locale: "tr", caption: "Sadece ekleyin,\nokumaya başlar",      subtitle: nil, content: multi()),
            Spec(name: "tr_03_highlight", locale: "tr", caption: "Nerede okuduğunu\nher zaman görün",    subtitle: nil, content: highlight()),
            Spec(name: "tr_04_voice",     locale: "tr", caption: "Hesap gerekmez,\nçevrimdışı çalışır",   subtitle: nil, content: voice()),
            // VI
            Spec(name: "vi_01_home",      locale: "vi", caption: "Đọc to PDF,\nsách và web",         subtitle: nil, content: home("Narrator")),
            Spec(name: "vi_02_multi",     locale: "vi", caption: "Chỉ cần thêm vào,\nnó sẽ đọc",     subtitle: nil, content: multi()),
            Spec(name: "vi_03_highlight", locale: "vi", caption: "Luôn thấy đang\nđọc tới đâu",      subtitle: nil, content: highlight()),
            Spec(name: "vi_04_voice",     locale: "vi", caption: "Không cần tài khoản,\ndùng offline",  subtitle: nil, content: voice()),
        ]
    }
}
