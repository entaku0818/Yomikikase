//
//  LanguageVoiceMapper.swift
//  VoiceYourText
//
//  言語コードから Cloud Run TTS のボイスID / ロケールへ変換する純粋ロジック。
//  View から切り出してユニットテスト可能にする。
//

import Foundation

/// 言語コードを Cloud TTS 用のボイスID・ロケールへマッピングする純粋関数群。
enum LanguageVoiceMapper {

    /// 言語コードを Cloud Run TTS のボイスIDへ変換する。
    /// 未知の言語コードは日本語ボイスへフォールバックする。
    static func voiceId(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "ja", "ja-jp":
            return "ja-jp-female-a"
        case "en", "en-us", "en-gb":
            return "en-us-female-a"
        case "de", "de-de":
            return "de-de-female-a"
        case "es", "es-es":
            return "es-es-female-a"
        case "fr", "fr-fr":
            return "fr-fr-female-a"
        case "it", "it-it":
            return "it-it-female-a"
        case "ko", "ko-kr":
            return "ko-kr-female-a"
        case "tr", "tr-tr":
            return "tr-tr-female-a"
        case "vi", "vi-vn":
            return "vi-vn-female-a"
        case "th", "th-th":
            return "th-th-female-a"
        case "zh", "zh-cn", "zh-hans":
            return "zh-cn-female-a"
        case "pt", "pt-br", "pt-pt":
            return "pt-br-female-a"
        case "ru", "ru-ru":
            return "ru-ru-female-a"
        default:
            return "ja-jp-female-a"
        }
    }

    /// 短い言語コードを Cloud TTS API 用のフルロケールへ変換する。
    /// 中国語は Google Cloud TTS 仕様で `cmn-CN`（`zh-CN` ではない）を返す。
    /// 未知の言語コードは日本語ロケールへフォールバックする。
    static func locale(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "ja", "ja-jp":
            return "ja-JP"
        case "en", "en-us":
            return "en-US"
        case "en-gb":
            return "en-GB"
        case "de", "de-de":
            return "de-DE"
        case "es", "es-es":
            return "es-ES"
        case "fr", "fr-fr":
            return "fr-FR"
        case "it", "it-it":
            return "it-IT"
        case "ko", "ko-kr":
            return "ko-KR"
        case "tr", "tr-tr":
            return "tr-TR"
        case "vi", "vi-vn":
            return "vi-VN"
        case "th", "th-th":
            return "th-TH"
        case "zh", "zh-cn", "zh-hans":
            return "cmn-CN"
        case "pt", "pt-br", "pt-pt":
            return "pt-BR"
        case "ru", "ru-ru":
            return "ru-RU"
        default:
            return "ja-JP"
        }
    }
}
