//
//  ScreenshotDemoSeeder.swift
//  VoiceYourText
//
//  App Store スクリーンショット撮影用のデモデータ投入（DEBUG ビルドのみ）。
//  起動引数 `-ScreenshotSeed ja|en` で、Core Data のテキストと Documents の PDF を入れる。
//  撮影は VoiceYourTextUITests/AppStoreScreenshotTests.swift → iOS/scripts/appstore_screenshots.sh。
//

#if DEBUG
import Foundation
import UIKit

enum ScreenshotDemoSeeder {
    static let launchArgument = "ScreenshotSeed"
    private static let seededKey = "ScreenshotSeedDone"

    /// 起動引数で言語が指定されていれば、初回だけデモデータを入れる
    static func seedIfRequested() {
        guard let code = UserDefaults.standard.string(forKey: launchArgument),
              let content = DemoContent.all[code] else {
            return
        }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else {
            return
        }

        defaults.set(code, forKey: "LanguageSetting")
        let repository = SpeechTextRepository.shared
        let language = SpeechTextRepository.LanguageSetting(rawValue: code) ?? .english
        // 一覧は新しい順に並ぶので、見せたい順の逆から入れる
        for item in content.texts.reversed() {
            repository.insert(title: item.title, text: item.text, languageSetting: language, fileType: item.fileType)
            Thread.sleep(forTimeInterval: 0.02)
        }
        writePDF(content.pdf)
        defaults.set(true, forKey: seededKey)
    }

    private static func writePDF(_ pdf: DemoContent.PDF) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = documents.appendingPathComponent(pdf.fileName)
        let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let margin: CGFloat = 56
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.paragraphSpacing = 12
        try? renderer.writePDF(to: url) { context in
            context.beginPage()
            let title = NSAttributedString(string: pdf.title, attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ])
            title.draw(in: CGRect(x: margin, y: margin, width: page.width - margin * 2, height: 60))
            let body = NSAttributedString(string: pdf.body, attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraph
            ])
            body.draw(in: CGRect(x: margin, y: margin + 64, width: page.width - margin * 2, height: page.height - margin * 2 - 64))
        }
    }
}

private struct DemoContent {
    struct Item {
        let title: String
        let text: String
        let fileType: String?
    }

    struct PDF {
        let fileName: String
        let title: String
        let body: String
    }

    let texts: [Item]
    let pdf: PDF

    static let all: [String: DemoContent] = ["ja": ja, "en": en]

    static let ja = DemoContent(
        texts: [
            Item(
                title: "吾輩は猫である",
                text: [
                    "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。吾輩はここで始めて人間というものを見た。",
                    "しかもあとで聞くとそれは書生という人間中で一番獰悪な種族であったそうだ。この書生というのは時々我々を捕えて煮て食うという話である。しかしその当時は何という考もなかったから別段恐しいとも思わなかった。",
                    "ただ彼の掌に載せられてスーと持ち上げられた時何だかフワフワした感じがあったばかりである。\n\n掌の上で少し落ちついて書生の顔を見たのがいわゆる人間というものの見始であろう。",
                    "この時妙なものだと思った感じが今でも残っている。第一毛をもって装飾されべきはずの顔がつるつるしてまるで薬缶だ。その後猫にもだいぶ逢ったがこんな片輪には一度も出会わした事がない。のみならず顔の真中があまりに突起している。",
                    "そうしてその穴の中から時々ぷうぷうと煙を吹く。"
                ].joined(),
                fileType: "aozora"
            ),
            Item(
                title: "今週の打ち合わせメモ",
                text: "来週のリリースに向けて、残りの作業を確認しました。デザインの最終確認は火曜日、テストは水曜日から金曜日に行います。移動中や家事の合間にも、このメモを聴いて内容を思い出せるようにしておきましょう。",
                fileType: nil
            ),
            Item(
                title: "走れメロス",
                text: "メロスは激怒した。必ず、かの邪智暴虐の王を除かなければならぬと決意した。メロスには政治がわからぬ。メロスは、村の牧人である。笛を吹き、羊と遊んで暮して来た。けれども邪悪に対しては、人一倍に敏感であった。",
                fileType: "aozora"
            ),
            Item(
                title: "こころ",
                text: "私はその人を常に先生と呼んでいた。だからここでもただ先生と書くだけで本名は打ち明けない。これは世間を憚かる遠慮というよりも、その方が私にとって自然だからである。",
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "睡眠と集中力レポート.pdf",
            title: "睡眠と集中力についてのレポート",
            body: [
                "よく眠れた日は、仕事や勉強の集中力が高く保たれることが知られています。本レポートでは、毎日の睡眠時間と、日中の作業効率の関係を三か月にわたって記録しました。\n\n結果として、睡眠が七時間を超えた日は、",
                "午前中の作業がもっとも捗る傾向が見られました。一方で、寝る直前までスマートフォンの画面を見ていた日は、寝つきが悪くなる傾向がありました。\n\n画面を見る時間を減らすために、夜は文章を目で読むのではなく、",
                "耳で聴く方法を試しました。目を休めながら情報を受け取れるため、続けやすいという声が多く集まりました。"
            ].joined()
        )
    )

    static let en = DemoContent(
        texts: [
            Item(
                title: "Alice's Adventures in Wonderland",
                text: [
                    "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once ",
                    "or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, ",
                    "\"and what is the use of a book,\" thought Alice, \"without pictures or conversations?\" So she was ",
                    "considering in her own mind whether the pleasure of making a daisy-chain would be worth the trouble of ",
                    "getting up and picking the daisies, when suddenly a White Rabbit with pink eyes ran close by her.\n\nThere ",
                    "was nothing so very remarkable in that; nor did Alice think it so very much out of the way to hear the Rabbit ",
                    "say to itself, \"Oh dear! Oh dear! I shall be late!\" But when the Rabbit actually took a watch out of its ",
                    "waistcoat-pocket, and looked at it, and then hurried on, Alice started to her feet, for it flashed across her ",
                    "mind that she had never before seen a rabbit with either a waistcoat-pocket, or a watch to take out of it."
                ].joined(),
                fileType: "epub"
            ),
            Item(
                title: "Weekly Team Notes",
                text: [
                    "We reviewed the remaining work for next week's release. Design sign-off is on Tuesday, and testing runs from ",
                    "Wednesday to Friday. Listen to these notes on your commute so everyone starts the week on the same page."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "Pride and Prejudice",
                text: [
                    "It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of ",
                    "a wife. However little known the feelings or views of such a man may be on his first entering a ",
                    "neighbourhood, this truth is so well fixed in the minds of the surrounding families, that he is considered ",
                    "the rightful property of some one or other of their daughters."
                ].joined(),
                fileType: nil
            ),
            Item(
                title: "The Adventures of Sherlock Holmes",
                text: "To Sherlock Holmes she is always the woman. I have seldom heard him mention her under any other name. In his eyes she eclipses and predominates the whole of her sex.",
                fileType: "epub"
            )
        ],
        pdf: PDF(
            fileName: "Sleep and Focus Report.pdf",
            title: "Sleep and Focus: A Three-Month Study",
            body: [
                "On days after a good night's sleep, people tend to stay focused at work and school for longer. This report ",
                "tracks daily sleep and daytime productivity over three months.\n\nOn nights with more than seven hours of ",
                "sleep, the following morning was consistently the most productive part of the day. Looking at a phone screen ",
                "right before bed, on the other hand, made it harder to fall asleep.\n\nTo cut down on screen time, ",
                "participants tried listening to articles in the evening instead of reading them. Resting their eyes while ",
                "still taking in information made the habit much easier to keep."
            ].joined()
        )
    )
}
#endif
