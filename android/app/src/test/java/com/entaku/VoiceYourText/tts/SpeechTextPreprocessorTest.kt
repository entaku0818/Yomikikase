package com.entaku.VoiceYourText.tts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS `SpeechTextPreprocessorTests.swift` と同じケース */
class SpeechTextPreprocessorTest {

    private fun spoken(text: String, language: String? = "ja") =
        SpeechTextPreprocessor.prepare(text, language).spoken

    @Test fun 日本語文中の英略語をカタカナ読みにする() {
        assertEquals("ピーディーエフを開く", spoken("PDFを開く"))
        assertEquals("ユーアールエルをコピー", spoken("URLをコピー"))
        assertEquals("アイオーエスアプリ", spoken("iOSアプリ"))
        assertEquals("ワイファイに接続", spoken("Wi-Fiに接続"))
    }

    @Test fun 英単語の一部に含まれる略語は置換しない() {
        assertEquals("MYPDFFILE", spoken("MYPDFFILE"))
        assertEquals("AIDを確認", spoken("AIDを確認"))
        assertEquals("IDEAを出す", spoken("IDEAを出す"))
    }

    @Test fun 略語が単独で現れる場合は置換する() {
        assertEquals("形式はシーエスブイ、または ジェイソン", spoken("形式はCSV、または JSON"))
    }

    @Test fun 数字に続く単位をカタカナ読みにする() {
        assertEquals("5キロメートル走った", spoken("5km走った"))
        assertEquals("体重は60キログラムです", spoken("体重は60kgです"))
        assertEquals("容量は500メガバイト", spoken("容量は500MB"))
        assertEquals("１２センチメートル", spoken("１２cm"))
    }

    @Test fun 数字が前に無い単位は置換しない() {
        assertEquals("kmという単位", spoken("kmという単位"))
        assertEquals("スペースキー", spoken("スペースキー"))
    }

    @Test fun 桁区切りカンマを外す() {
        assertEquals("売上は1234円", spoken("売上は1,234円"))
        assertEquals("1234567", spoken("1,234,567"))
    }

    @Test fun 三桁区切りでないカンマは残す() {
        assertEquals("1,23", spoken("1,23"))
        assertEquals("項目A,項目B", spoken("項目A,項目B"))
    }

    @Test fun パーセントと摂氏を読みにする() {
        assertEquals("達成率は80パーセントです", spoken("達成率は80%です"))
        assertEquals("気温は25度", spoken("気温は25℃"))
    }

    @Test fun 英語では日本語向けルールを適用しない() {
        assertEquals("Open the PDF file", spoken("Open the PDF file", "en"))
        assertEquals("It is 5km away", spoken("It is 5km away", "en"))
        assertEquals("Total 1,234 items", spoken("Total 1,234 items", "en"))
        assertEquals("80% done", spoken("80% done", "en-US"))
    }

    @Test fun その他の言語でも日本語向けルールを適用しない() {
        listOf("de", "es", "fr", "it", "ko", "zh", "pt", "ru", "th", "vi").forEach {
            assertEquals("$it で誤発火", "PDF 1,234 5km 80%", spoken("PDF 1,234 5km 80%", it))
        }
    }

    @Test fun 言語がnullなら日本語向けルールを適用しない() {
        assertEquals("PDFを開く", spoken("PDFを開く", null))
    }

    @Test fun 変換が無ければ元テキストと同一() {
        val prepared = SpeechTextPreprocessor.prepare("こんにちは", "ja")
        assertTrue(prepared.isIdentity)
        assertEquals("こんにちは", prepared.spoken)
    }

    @Test fun 置換後の範囲が元テキストの範囲に逆引きできる() {
        val prepared = SpeechTextPreprocessor.prepare("PDFを開く", "ja")
        assertEquals("ピーディーエフを開く", prepared.spoken)
        assertEquals(TextRange(0, 3), prepared.originalRange(TextRange(2, 2)))
        assertEquals(TextRange(3, 1), prepared.originalRange(TextRange(7, 1)))
    }

    @Test fun 置換が短くなる場合も後続の範囲が正しくずれる() {
        val prepared = SpeechTextPreprocessor.prepare("金額は1,234円です", "ja")
        assertEquals("金額は1234円です", prepared.spoken)
        assertEquals(TextRange(8, 1), prepared.originalRange(TextRange(7, 1)))
    }

    @Test fun 空文字は変換なし() {
        val prepared = SpeechTextPreprocessor.prepare("", "ja")
        assertEquals("", prepared.spoken)
        assertTrue(prepared.isIdentity)
        assertNull(prepared.originalRange(TextRange(0, 0)))
    }

    @Test fun セグメントは元テキストとspokenを隙間なく覆う() {
        val original = "PDFは1,234円で5kmの距離、iOSにも対応"
        val prepared = SpeechTextPreprocessor.prepare(original, "ja")
        assertEquals(original.length, prepared.segments.sumOf { it.original.length })
        assertEquals(prepared.spoken.length, prepared.segments.sumOf { it.spoken.length })
        var expectedOriginal = 0
        var expectedSpoken = 0
        prepared.segments.forEach {
            assertEquals(expectedOriginal, it.original.start)
            assertEquals(expectedSpoken, it.spoken.start)
            expectedOriginal = it.original.end
            expectedSpoken = it.spoken.end
        }
    }

    @Test fun 日本語の文中改行は詰める() = assertEquals("読み上げナレーター", spoken("読み上げ\nナレーター"))

    @Test fun 句点で終わる行の改行は残す() =
        assertEquals("これは一文目です。\n次の文です。", spoken("これは一文目です。\n次の文です。"))

    @Test fun 空行は段落区切りとして残す() = assertEquals("前の段落\n\n次の段落", spoken("前の段落\n\n次の段落"))

    @Test fun 閉じ括弧で終わる行の改行は残す() =
        assertEquals("彼は「そうだ」\nと言った", spoken("彼は「そうだ」\nと言った"))

    @Test fun 次の行が箇条書きなら詰めない() {
        assertEquals("次のとおり\n・ひとつめ", spoken("次のとおり\n・ひとつめ"))
        assertEquals("次のとおり\n1. ひとつめ", spoken("次のとおり\n1. ひとつめ"))
    }

    @Test fun 読点で終わる行は詰める() =
        assertEquals("まず準備をして、次に実行する", spoken("まず準備をして、\n次に実行する"))

    @Test fun 英語の文中改行は半角スペースで繋ぐ() = assertEquals("hello world", spoken("hello\nworld", "en"))

    @Test fun 英語のハイフネーションを解除する() {
        assertEquals("narrator", spoken("narra-\ntor", "en"))
        assertEquals("ナレー-\nション", spoken("ナレー-\nション", "ja"))
    }

    @Test fun 英語のピリオドで終わる行は繋がない() =
        assertEquals("First line.\nSecond line", spoken("First line.\nSecond line", "en"))

    @Test fun 改行を詰めてもハイライト範囲は元テキストを指す() {
        val original = "読み上げ\nナレーター"
        val prepared = SpeechTextPreprocessor.prepare(original, "ja")
        val mapped = prepared.originalRange(TextRange(4, 5))
        assertNotNull(mapped)
        assertEquals("ナレーター", original.substring(mapped!!.start, mapped.end).replace("\n", ""))
        assertEquals(original.length, mapped.end)
    }

    @Test fun 改行整形は辞書の読み替えと共存する() {
        val prepared = SpeechTextPreprocessor.prepare("設定から\n東京を選ぶ", "ja", listOf("東京" to "とうきょう"))
        assertEquals("設定からとうきょうを選ぶ", prepared.spoken)
    }
}
