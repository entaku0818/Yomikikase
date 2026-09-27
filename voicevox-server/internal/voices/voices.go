// Package voices は、アプリに公開する VOICEVOX の声の許可リスト。
//
// ここに載っているのは、有料アプリで申請なしに使えることを各キャラの利用規約で確認した声だけ
// （2026-09-27 時点）。声を足すときは、キャラの規約（商用可否・申請要否・クレジット書式）を
// 確認してから追加すること。
package voices

// Voice は VOICEVOX の1スタイル。
type Voice struct {
	// SpeakerID は VOICEVOX エンジンの style id。
	SpeakerID int `json:"speakerId"`
	// Character はキャラ名。
	Character string `json:"character"`
	// Style はスタイル名（ノーマルなど）。
	Style string `json:"style"`
	// Credit はアプリ内に表示するクレジット表記（キャラ規約の指定どおり）。
	Credit string `json:"credit"`
	// TermsURL はキャラの利用規約。
	TermsURL string `json:"termsUrl"`
}

// All はアプリに公開する声。並び順はアプリの表示順。
var All = []Voice{
	{SpeakerID: 14, Character: "冥鳴ひまり", Style: "ノーマル", Credit: "VOICEVOX:冥鳴ひまり", TermsURL: "https://meimeihimari.wixsite.com/himari/terms-of-use"},
	{SpeakerID: 3, Character: "ずんだもん", Style: "ノーマル", Credit: "VOICEVOX:ずんだもん", TermsURL: "https://zunko.jp/con_ongen_kiyaku.html"},
	{SpeakerID: 2, Character: "四国めたん", Style: "ノーマル", Credit: "VOICEVOX:四国めたん", TermsURL: "https://zunko.jp/con_ongen_kiyaku.html"},
	{SpeakerID: 11, Character: "玄野武宏", Style: "ノーマル", Credit: "VOICEVOX:玄野武宏(CV:ガロ)", TermsURL: "https://www.virvoxproject.com/voicevoxの利用規約"},
	{SpeakerID: 12, Character: "白上虎太郎", Style: "ふつう", Credit: "VOICEVOX:白上虎太郎", TermsURL: "https://www.virvoxproject.com/voicevoxの利用規約"},
	{SpeakerID: 9, Character: "波音リツ", Style: "ノーマル", Credit: "VOICEVOX:波音リツ", TermsURL: "https://www.canon-voice.com/terms"},
}

// Find は許可リストから声を探す。
func Find(speakerID int) (Voice, bool) {
	for _, v := range All {
		if v.SpeakerID == speakerID {
			return v, true
		}
	}
	return Voice{}, false
}
