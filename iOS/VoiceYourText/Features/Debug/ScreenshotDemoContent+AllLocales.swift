#if DEBUG
import Foundation

extension ScreenshotDemoContent {
    private struct LocalizedSample: Decodable {
        let title: String
        let text: String
        let title2: String
        let text2: String
        let title3: String
        let text3: String
        let pdfTitle: String
        let pdfText: String
    }

    static func localized(_ code: String) -> ScreenshotDemoContent? {
        // Keep the established samples for the original locales.
        if let content = all[code] { return content }
        guard let url = Bundle.main.url(forResource: "ScreenshotSamples", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let samples = try? JSONDecoder().decode([String: LocalizedSample].self, from: data),
              let sample = samples[code] else { return nil }
        return ScreenshotDemoContent(
            texts: [
                Item(title: sample.title, text: sample.text, fileType: "epub"),
                Item(title: sample.title2, text: sample.text2, fileType: nil),
                Item(title: sample.title3, text: sample.text3, fileType: "epub")
            ],
            pdf: PDF(fileName: sample.pdfTitle + ".pdf", title: sample.pdfTitle, body: sample.pdfText),
            dictionary: [("SQL", "sequel"), ("OpenAI", "open A I")]
        )
    }
}
#endif
