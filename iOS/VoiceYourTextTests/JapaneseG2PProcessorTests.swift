//
//  JapaneseG2PProcessorTests.swift
//  VoiceYourTextTests
//
//  Kokoro 日本語 G2P の回帰テスト。
//  ここで守りたい不変条件は「Kokoro の語彙に無い文字を出さない」こと。
//  語彙外の文字は Tokenizer.tokenize が無言で捨てるため、
//  音が丸ごと消えても誰も気付けない（実際に /g/ が全滅していた）。
//

import XCTest
@testable import VoiceYourText

final class JapaneseG2PProcessorTests: XCTestCase {

    /// Kokoro の語彙にある唯一の ASCII 抜け。`g`(U+0067) は無く `ɡ`(U+0261) だけがある。
    private let asciiG: Character = "g"

    private let allKana = """
        あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん\
        がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ\
        きゃきゅきょしゃしゅしょちゃちゅちょにゃにゅにょひゃひゅひょみゃみゅみょりゃりゅりょ\
        ぎゃぎゅぎょじゃじゅじょびゃびゅびょぴゃぴゅぴょ\
        ふぁふぃふぇふぉてぃでぃとぅどぅしぇちぇじぇつぁつぃつぇつぉゔぁゔぃゔぇゔぉゔ\
        ぁぃぅぇぉゃゅょゎっーん
        """

    // MARK: - /g/ が消えないこと（Issue: 日本語の が行 が無音だった）

    /// が行は IPA の `ɡ`(U+0261) で出す。ASCII の `g` は Kokoro の語彙に無い。
    func test_gaRow_usesIPAVoicedVelarStop_notASCIIG() {
        XCTAssertEqual(JapaneseG2PProcessor.hiraganaToIPA("が"), "ɡa")
        XCTAssertEqual(JapaneseG2PProcessor.hiraganaToIPA("ぎゅ"), "ɡjɯ")
        XCTAssertEqual(JapaneseG2PProcessor.hiraganaToIPA("かながわ"), "kanaɡawa")
    }

    /// 音素表のどの経路からも ASCII `g` が出ないこと。
    func test_phonemeTable_neverEmitsASCIIG() {
        let ipa = JapaneseG2PProcessor.hiraganaToIPA(allKana)
        XCTAssertFalse(ipa.contains(asciiG), "ASCII g は Kokoro の語彙に無いため無音になる: \(ipa)")
    }

    /// 全かなを通しても Kokoro の語彙外の文字が出ないこと。
    /// バンドルに config.json が無い環境ではスキップする。
    func test_allKana_producesOnlyVocabularyCharacters() throws {
        let vocab = try loadKokoroVocabulary()
        let ipa = JapaneseG2PProcessor.hiraganaToIPA(allKana)
        let unknown = Set(ipa.filter { vocab[String($0)] == nil })
        XCTAssertTrue(unknown.isEmpty, "語彙外の文字が出ている: \(unknown.sorted())")
    }

    // MARK: - 句読点（トークナイザは半角形を返すので畳まないと区切りが消える）

    /// CFStringTokenizer が返す半角の `｡`/`､`/`｢` を全角に畳んでから音素表に当てる。
    func test_normalizeReading_foldsHalfwidthPunctuation() {
        XCTAssertEqual(JapaneseG2PProcessor.normalizeReading("あ｡い､う｢え｣"), "あ。い、う「え」")
    }

    /// 読点は間（スペース）、句点は文末（ピリオド）として音素列に残る。
    func test_punctuation_survivesAsPause() {
        let ipa = JapaneseG2PProcessor.hiraganaToIPA(JapaneseG2PProcessor.normalizeReading("あい｡うえ"))
        XCTAssertEqual(ipa, "ai. ɯe")

        let comma = JapaneseG2PProcessor.hiraganaToIPA(JapaneseG2PProcessor.normalizeReading("あい､うえ"))
        XCTAssertEqual(comma, "ai ɯe")
    }

    // MARK: - 長音

    /// 「おう」は長音 `oː`。`oɯ` のままだと語末に /u/ が立って不自然になる。
    func test_applyLongVowels_foldsOUIntoLongO() {
        XCTAssertEqual(JapaneseG2PProcessor.applyLongVowels("toɯkjoɯ"), "toːkjoː")
        XCTAssertEqual(JapaneseG2PProcessor.hiraganaToIPA("とうきょう"), "toːkjoː")
        XCTAssertEqual(JapaneseG2PProcessor.hiraganaToIPA("ありがとう"), "aɾiɡatoː")
    }

    /// 同一母音の連続は形態素境界をまたぐことがあるので畳まない（`県に行く`→`ɲii`）。
    func test_applyLongVowels_keepsIdenticalVowelPairs() {
        XCTAssertEqual(JapaneseG2PProcessor.applyLongVowels("ɲiikɯ"), "ɲiikɯ")
        XCTAssertEqual(JapaneseG2PProcessor.applyLongVowels("okaasaɴ"), "okaasaɴ")
    }

    // MARK: - 数字

    func test_readNumber_singleDigits() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("0"), "ぜろ")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("7"), "なな")
    }

    func test_readNumber_placesAndSoundChanges() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("10"), "じゅう")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("100"), "ひゃく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("300"), "さんびゃく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("600"), "ろっぴゃく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("800"), "はっぴゃく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("1000"), "せん")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("3000"), "さんぜん")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("8000"), "はっせん")
    }

    func test_readNumber_myriadUnits() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("10000"), "いちまん")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("1400"), "せんよんひゃく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("14000000"), "せんよんひゃくまん")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("100000000"), "いちおく")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("1000000000000"), "いっちょう")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("2026"), "にせんにじゅうろく")
    }

    func test_readNumber_leadingZerosAreDropped() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("09"), "きゅう")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("000"), "ぜろ")
    }

    func test_readNumber_decimals() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("3.14"), "さんてんいちよん")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("1.5"), "いちてんご")
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("0.05"), "ぜろてんぜろご")
    }

    /// 兆を超える桁は位取りを諦めて1桁ずつ読む（無音にはしない）。
    func test_readNumber_beyondTrillion_readsDigitByDigit() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumber("12345678901234567"),
                       "いちにさんよんごろくななはちきゅうぜろいちにさんよんごろくなな")
    }

    /// 桁区切りのカンマは数値の一部として飲み込む。区切りでないカンマは文の区切りとして残す。
    func test_readNumbers_thousandsSeparator() {
        XCTAssertEqual(JapaneseG2PProcessor.readNumbers("1,980円"), "せんきゅうひゃくはちじゅう円")
        XCTAssertEqual(JapaneseG2PProcessor.readNumbers("1,2"), "いち,に")
    }

    // MARK: - ラテン文字

    /// 略語は1文字ずつアルファベット読み。
    func test_readLatin_acronym_readsLetterByLetter() {
        XCTAssertEqual(JapaneseG2PProcessor.readLatin("iOS"), "あいおーえす")
        XCTAssertEqual(JapaneseG2PProcessor.readLatin("EPUB"), "いーぴーゆーびー")
        XCTAssertEqual(JapaneseG2PProcessor.readLatin("TTS"), "てぃーてぃーえす")
    }

    /// 語らしい並びはローマ字→かな変換に任せる。いずれにせよ無音にはしない。
    func test_readLatin_word_isNeverSilent() {
        let reading = JapaneseG2PProcessor.readLatin("screenshot")
        XCTAssertFalse(reading.isEmpty)
        XCTAssertFalse(reading.contains(where: { $0.isASCII && $0.isLetter }))
    }

    // MARK: - パイプライン全体

    /// 数字はトークナイザに渡す前にかなへ開く。
    /// CFStringTokenizer は `0.5秒`→`5びょう` のように桁を落とし、`1人`→`1rén` とピンインを混ぜる。
    func test_prepareForTokenization_opensNumbersBeforeTokenizing() {
        XCTAssertEqual(JapaneseG2PProcessor.prepareForTokenization("0.5秒"), "ぜろてんご秒")
        XCTAssertEqual(JapaneseG2PProcessor.prepareForTokenization("1,400円"), "せんよんひゃく円")
        XCTAssertEqual(JapaneseG2PProcessor.prepareForTokenization("２０２６年"), "にせんにじゅうろく年")
    }

    /// 日本語テキストを通しても語彙外の文字が出ないこと（実文で回帰）。
    func test_process_realSentences_produceOnlyVocabularyCharacters() throws {
        let vocab = try loadKokoroVocabulary()
        let processor = JapaneseG2PProcessor()
        let sentences = [
            "神奈川県に行きます。",
            "東京都の人口は1400万人です。",
            "2026年9月19日、気温は28度でした。",
            "iOSとGoogleで、PDFを読む。",
            "円周率は3.14です",
            "「こんにちは」と彼は言った。",
            "コンピューターの画面",
            "ヴァイオリンとジェットコースター",
        ]
        for sentence in sentences {
            let (ipa, _) = try processor.process(input: sentence)
            XCTAssertFalse(ipa.isEmpty, "無音になった: \(sentence)")
            let unknown = Set(ipa.filter { vocab[String($0)] == nil })
            XCTAssertTrue(unknown.isEmpty, "\(sentence) で語彙外の文字: \(unknown.sorted())")
        }
    }

    /// 「神奈川」の /g/ が音素列に残っていること（修正前は丸ごと消えていた）。
    func test_process_keepsVoicedVelarStop() throws {
        let processor = JapaneseG2PProcessor()
        let (ipa, _) = try processor.process(input: "神奈川に行く")
        XCTAssertTrue(ipa.contains("ɡ"), "ɡ が消えている: \(ipa)")
        XCTAssertFalse(ipa.contains(asciiG))
    }

    func test_setLanguage_rejectsNonJapanese() {
        let processor = JapaneseG2PProcessor()
        XCTAssertNoThrow(try processor.setLanguage(.ja))
        XCTAssertThrowsError(try processor.setLanguage(.enUS))
    }

    // MARK: - Helpers

    /// app bundle の config.json から Kokoro の語彙を読む。
    private func loadKokoroVocabulary() throws -> [String: Int] {
        guard let url = Bundle.main.url(forResource: KokoroBundleResource.config, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vocab = json["vocab"] as? [String: Int] else {
            throw XCTSkip("config.json をテストホストのバンドルから読めなかった")
        }
        return vocab
    }
}
