//
//  ScreenshotViewV2.swift
//  VoiceYourText
//
//  App Store / Google Play 審査提出用スクリーンショット（6枚 × 10ロケール）。
//
//  旧 ScreenshotView.swift の問題を3点まとめて解消する:
//   1. 端末内コンテンツが全ロケール日本語ハードコード → ShotStrings で完全ローカライズ
//   2. 実機と構成が違う（タブバー無し / 322pt レイアウトでフォントが巨大）
//      → 実機と同じ 3タブ・430pt(iPhone) / 1024pt(iPad) で組み、フレームには縮小して貼る
//   3. リアリティ不足（PDF 本文・マイファイル一覧が空）
//      → ステータスバー・紙面レイアウト・進捗つきリスト・ミニプレイヤーを実データ相当で描画
//
//  ImageRenderer / Preview の制約に合わせた既存の作法は踏襲する:
//   - ScrollView は空白になるので使わない（VStack で直接積む）
//   - UIKit ラップの Slider は描画できないので MockSlider を使う
//   - Color アセット参照は解決されないのでリテラル値で持つ
//

import SwiftUI

#if DEBUG

// MARK: - パレット（DesignSystem/tokens.md 準拠）

private enum ShotTheme {
    static let accent      = Color(red: 75/255, green: 71/255, blue: 224/255)   // #4B47E0
    static let accentSoft  = accent.opacity(0.12)
    static let onAccent    = Color.white
    static let canvas      = accent.opacity(0.06)
    static let card        = Color.white
    static let grouped     = Color(red: 0.949, green: 0.949, blue: 0.969)       // #F2F2F7
    static let label       = Color(red: 0.110, green: 0.110, blue: 0.118)       // #1C1C1E
    static let secondary   = Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.6)
    static let tertiary    = Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3)
    static let separator   = Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.2)
    static let destructive = Color(red: 0.878, green: 0.192, blue: 0.192)
}

// MARK: - ロケールごとの表示文言

/// 端末内に描画するすべての文字列。**ここに無い文字列を View 側に直書きしないこと。**
/// 見出し（caption/subtitle）も含めて 1 ロケール 1 定義にまとめ、
/// 「見出しはタイ語なのに端末内は日本語」という審査で目立つ不整合を構造的に防ぐ。
struct ShotStrings {
    /// このロケールの言語コード（"ja" / "en" …）。04 言語画面で「どの行が選択済みか」を
    /// 決めるのに使う。ここが無いと全ロケールで日本語が選択済みに見えてしまう。
    let code: String
    // ナビゲーション / タブ
    let navHome: String, navFiles: String, navSettings: String
    let tabHome: String, tabFiles: String, tabSettings: String
    // ホーム
    let greeting: String, recent: String
    let tileText: String, tileTxt: String, tileDrive: String
    let tileBook: String, tileScan: String, tileLink: String
    // マイファイル
    let search: String
    let filters: [String]          // すべて / PDF / テキスト / 本
    let types: [String]            // PDF / テキスト / 電子書籍 / スキャン / Web
    let done: String, unplayed: String, playing: String
    // 言語
    let langScreen: String, langSection: String
    // 設定
    let voiceSec: String, voicePick: String, voiceName: String
    let speed: String, pitch: String, normalValue: String
    let slow: String, normal: String, fast: String, low: String, high: String
    let dictSec: String, userDict: String, dictCount: String
    let cacheSec: String, cache: String, clear: String
    let supportSec: String, contact: String
    // 読み上げ対象作品（各ロケールのパブリックドメイン作品）
    let file: String, chapter: String, pageLabel: String
    let highlight: String
    let paraA: String, paraAEnd: String, paraB: String, paraC: String
    let readDone: String, nowLead: String, nowTail: String, nextPara: String
    // マイファイル行（タイトル, サイズ, 進捗%）
    let items: [(String, String, Int)]
    // 見出し 6 枚分（caption, subtitle）
    let caps: [(String, String)]
}

extension ShotStrings {
    static let ja = ShotStrings(
        code: "ja",
        navHome: "ナレーター", navFiles: "マイファイル", navSettings: "設定",
        tabHome: "ホーム", tabFiles: "マイファイル", tabSettings: "設定",
        greeting: "読みたいものを、声で。", recent: "最近のファイル",
        tileText: "テキスト", tileTxt: "TXTファイル", tileDrive: "Gドライブ",
        tileBook: "本", tileScan: "スキャン", tileLink: "リンク",
        search: "ファイルを検索",
        filters: ["すべて", "PDF", "テキスト", "本"],
        types: ["PDF", "テキスト", "電子書籍", "スキャン", "Web"],
        done: "完了", unplayed: "未再生", playing: "再生中",
        langScreen: "読み上げ言語", langSection: "音声の言語（10言語）",
        voiceSec: "音声設定", voicePick: "音声の選択", voiceName: "Kyoko",
        speed: "声の速さ", pitch: "声の高さ", normalValue: "x1.0（標準）",
        slow: "遅い", normal: "標準 1.0", fast: "速い", low: "低い", high: "高い",
        dictSec: "辞書", userDict: "ユーザー辞書", dictCount: "12件",
        cacheSec: "キャッシュ", cache: "音声キャッシュ", clear: "クリア",
        supportSec: "サポート", contact: "お問い合わせ・フィードバック",
        file: "吾輩は猫である.pdf", chapter: "一", pageLabel: "3 / 12 ページ",
        highlight: "じめじめした",
        paraA: "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。何でも薄暗い",
        paraAEnd: "所でニャーニャー泣いていた事だけは記憶している。",
        paraB: "吾輩はここで始めて人間というものを見た。しかもあとで聞くとそれは書生という人間中で一番獰悪な種族であったそうだ。",
        paraC: "この書生というのは時々我々を捕えて煮て食うという話である。しかしその当時は何という考もなかったから別段恐しいとも思わなかった。",
        readDone: "吾輩は猫である。名前はまだ無い。",
        nowLead: "どこで生れたかとんと見当がつかぬ。何でも薄暗い",
        nowTail: "所でニャーニャー泣いていた事だけは記憶している。",
        nextPara: "吾輩はここで始めて人間というものを見た。しかもあとで聞くとそれは書生という人間中で一番獰悪な種族であったそうだ。",
        items: [("吾輩は猫である.pdf", "4.2 MB", 35), ("草枕 — 冒頭", "1,240字", 100),
                ("こころ.epub", "1.1 MB", 8), ("スキャン 3ページ", "OCR済み", 0),
                ("Wikipedia — 富士山", "3,800字", 50)],
        caps: [("読むより、聴く。", "テキスト・PDF・本・Web・スキャンをそのまま音声に"),
               ("PDFも、\n開けばすぐ声に。", "紙面のレイアウトそのまま、ページ順に読み上げ"),
               ("今読んでいる\n一文が、光る。", "目で追いながら聴けるハイライト表示"),
               ("10言語を、\nネイティブの声で", "日本語・英語・韓国語・タイ語ほか10言語に対応"),
               ("速さも高さも、\n思いのままに", "読み方はユーザー辞書に覚えさせておける"),
               ("途中でやめても、\n続きから。", "進捗と声の設定をファイルごとに記憶")]
    )

    static let en = ShotStrings(
        code: "en",
        navHome: "Narrator", navFiles: "My Files", navSettings: "Settings",
        tabHome: "Home", tabFiles: "My Files", tabSettings: "Settings",
        greeting: "Anything you want to read, out loud.", recent: "Recent files",
        tileText: "Text", tileTxt: "TXT file", tileDrive: "Drive",
        tileBook: "Books", tileScan: "Scan", tileLink: "Link",
        search: "Search files",
        filters: ["All", "PDF", "Text", "Books"],
        types: ["PDF", "Text", "eBook", "Scan", "Web"],
        done: "Finished", unplayed: "Not played", playing: "Now playing",
        langScreen: "Speech language", langSection: "Voice language (10 languages)",
        voiceSec: "VOICE", voicePick: "Voice", voiceName: "Samantha",
        speed: "Speed", pitch: "Pitch", normalValue: "x1.0 (Normal)",
        slow: "Slow", normal: "Normal 1.0", fast: "Fast", low: "Low", high: "High",
        dictSec: "DICTIONARY", userDict: "User dictionary", dictCount: "12",
        cacheSec: "CACHE", cache: "Audio cache", clear: "Clear",
        supportSec: "SUPPORT", contact: "Contact & feedback",
        file: "Alice in Wonderland.pdf", chapter: "CHAPTER I", pageLabel: "3 / 12 pages",
        highlight: "nothing to do",
        paraA: "Alice was beginning to get very tired of sitting by her sister on the bank, and of having ",
        paraAEnd: ": once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it.",
        paraB: "“And what is the use of a book,” thought Alice, “without pictures or conversations?”",
        paraC: "So she was considering in her own mind whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies.",
        readDone: "Alice was beginning to get very tired of sitting by her sister on the bank.",
        nowLead: "So she was considering in her own mind whether the pleasure of ",
        nowTail: " would be worth the trouble of getting up and picking the daisies.",
        nextPara: "When suddenly a White Rabbit with pink eyes ran close by her, and she heard it mutter to itself.",
        items: [("Alice in Wonderland.pdf", "4.2 MB", 35), ("Notes — Chapter 3", "1,240 words", 100),
                ("Pride and Prejudice.epub", "1.1 MB", 8), ("Scan · 3 pages", "OCR done", 0),
                ("Wikipedia — Mount Fuji", "3,800 words", 50)],
        caps: [("Listen instead\nof reading", "Text, PDF, books, web pages and scans — read aloud"),
               ("Open a PDF,\nhear it read", "Page order and layout kept exactly as printed"),
               ("The line being read\nlights up", "Follow along by eye while you listen"),
               ("10 languages,\nspoken natively", "English, Japanese, Korean, Thai and 6 more"),
               ("Set the speed\nand the pitch", "Teach it your own pronunciations with the dictionary"),
               ("Stop anywhere,\nresume anywhere", "Progress and voice settings saved per file")]
    )

    static let de = ShotStrings(
        code: "de",
        navHome: "Narrator", navFiles: "Meine Dateien", navSettings: "Einstellungen",
        tabHome: "Start", tabFiles: "Dateien", tabSettings: "Einstell.",
        greeting: "Alles, was du lesen willst — vorgelesen.", recent: "Zuletzt verwendet",
        tileText: "Text", tileTxt: "TXT-Datei", tileDrive: "Drive",
        tileBook: "Bücher", tileScan: "Scan", tileLink: "Link",
        search: "Dateien suchen",
        filters: ["Alle", "PDF", "Text", "Bücher"],
        types: ["PDF", "Text", "E-Book", "Scan", "Web"],
        done: "Fertig", unplayed: "Nicht gehört", playing: "Wird gespielt",
        langScreen: "Sprache der Stimme", langSection: "Stimmsprache (10 Sprachen)",
        voiceSec: "STIMME", voicePick: "Stimme", voiceName: "Anna",
        speed: "Geschwindigkeit", pitch: "Tonhöhe", normalValue: "x1.0 (Normal)",
        slow: "Langsam", normal: "Normal 1.0", fast: "Schnell", low: "Tief", high: "Hoch",
        dictSec: "WÖRTERBUCH", userDict: "Eigenes Wörterbuch", dictCount: "12",
        cacheSec: "CACHE", cache: "Audio-Cache", clear: "Leeren",
        supportSec: "SUPPORT", contact: "Kontakt & Feedback",
        file: "Die Verwandlung.pdf", chapter: "ERSTES KAPITEL", pageLabel: "3 / 12 Seiten",
        highlight: "unruhigen Träumen",
        paraA: "Als Gregor Samsa eines Morgens aus ",
        paraAEnd: " erwachte, fand er sich in seinem Bett zu einem ungeheueren Ungeziefer verwandelt.",
        paraB: "Er lag auf seinem panzerartig harten Rücken und sah, wenn er den Kopf ein wenig hob, seinen gewölbten, braunen Bauch.",
        paraC: "„Was ist mit mir geschehen?“ dachte er. Es war kein Traum. Sein Zimmer lag ruhig zwischen den vier bekannten Wänden.",
        readDone: "Als Gregor Samsa eines Morgens aus unruhigen Träumen erwachte.",
        nowLead: "Er lag auf seinem ", nowTail: " harten Rücken und sah seinen gewölbten, braunen Bauch.",
        nextPara: "„Was ist mit mir geschehen?“ dachte er. Es war kein Traum.",
        items: [("Die Verwandlung.pdf", "4,2 MB", 35), ("Notizen — Kapitel 3", "1.240 Wörter", 100),
                ("Faust.epub", "1,1 MB", 8), ("Scan · 3 Seiten", "OCR fertig", 0),
                ("Wikipedia — Fudschijama", "3.800 Wörter", 50)],
        caps: [("Hören statt\nlesen", "Text, PDF, Bücher, Webseiten und Scans — vorgelesen"),
               ("PDF öffnen,\nsofort hören", "Seitenfolge und Layout bleiben wie gedruckt"),
               ("Der gelesene Satz\nleuchtet auf", "Mit den Augen folgen, mit den Ohren lesen"),
               ("10 Sprachen,\nnativ gesprochen", "Deutsch, Englisch, Japanisch und 7 weitere"),
               ("Tempo und Tonhöhe\nnach Wunsch", "Eigene Aussprachen im Wörterbuch hinterlegen"),
               ("Jederzeit anhalten,\nweiterhören", "Fortschritt und Stimme pro Datei gespeichert")]
    )

    static let es = ShotStrings(
        code: "es",
        navHome: "Narrador", navFiles: "Mis archivos", navSettings: "Ajustes",
        tabHome: "Inicio", tabFiles: "Archivos", tabSettings: "Ajustes",
        greeting: "Todo lo que quieras leer, en voz alta.", recent: "Archivos recientes",
        tileText: "Texto", tileTxt: "Archivo TXT", tileDrive: "Drive",
        tileBook: "Libros", tileScan: "Escanear", tileLink: "Enlace",
        search: "Buscar archivos",
        filters: ["Todos", "PDF", "Texto", "Libros"],
        types: ["PDF", "Texto", "eBook", "Escaneo", "Web"],
        done: "Terminado", unplayed: "Sin escuchar", playing: "Reproduciendo",
        langScreen: "Idioma de la voz", langSection: "Idioma de la voz (10 idiomas)",
        voiceSec: "VOZ", voicePick: "Voz", voiceName: "Mónica",
        speed: "Velocidad", pitch: "Tono", normalValue: "x1.0 (Normal)",
        slow: "Lenta", normal: "Normal 1.0", fast: "Rápida", low: "Grave", high: "Agudo",
        dictSec: "DICCIONARIO", userDict: "Diccionario propio", dictCount: "12",
        cacheSec: "CACHÉ", cache: "Caché de audio", clear: "Borrar",
        supportSec: "SOPORTE", contact: "Contacto y comentarios",
        file: "Don Quijote.pdf", chapter: "CAPÍTULO PRIMERO", pageLabel: "3 / 12 páginas",
        highlight: "no quiero acordarme",
        paraA: "En un lugar de la Mancha, de cuyo nombre ",
        paraAEnd: ", no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor.",
        paraB: "Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro.",
        paraC: "Es, pues, de saber que este sobredicho hidalgo, los ratos que estaba ocioso, se daba a leer libros de caballerías con tanta afición y gusto.",
        readDone: "En un lugar de la Mancha, de cuyo nombre no quiero acordarme.",
        nowLead: "Frisaba la edad de nuestro hidalgo con ", nowTail: "; era de complexión recia, seco de carnes.",
        nextPara: "Es, pues, de saber que este sobredicho hidalgo se daba a leer libros de caballerías.",
        items: [("Don Quijote.pdf", "4,2 MB", 35), ("Notas — Capítulo 3", "1.240 palabras", 100),
                ("La Regenta.epub", "1,1 MB", 8), ("Escaneo · 3 páginas", "OCR listo", 0),
                ("Wikipedia — Monte Fuji", "3.800 palabras", 50)],
        caps: [("Escucha\nen vez de leer", "Texto, PDF, libros, webs y escaneos leídos en voz alta"),
               ("Abre un PDF\ny escúchalo", "Se respeta el orden y la maqueta de la página"),
               ("La frase que suena\nse ilumina", "Sigue con la vista mientras escuchas"),
               ("10 idiomas,\ncon voz nativa", "Español, inglés, japonés y 7 más"),
               ("Ajusta velocidad\ny tono", "Enséñale tus propias pronunciaciones"),
               ("Párate donde sea,\nsigue después", "Guarda el avance y la voz de cada archivo")]
    )

    static let fr = ShotStrings(
        code: "fr",
        navHome: "Narrateur", navFiles: "Mes fichiers", navSettings: "Réglages",
        tabHome: "Accueil", tabFiles: "Fichiers", tabSettings: "Réglages",
        greeting: "Tout ce que vous voulez lire, à voix haute.", recent: "Fichiers récents",
        tileText: "Texte", tileTxt: "Fichier TXT", tileDrive: "Drive",
        tileBook: "Livres", tileScan: "Scan", tileLink: "Lien",
        search: "Rechercher un fichier",
        filters: ["Tous", "PDF", "Texte", "Livres"],
        types: ["PDF", "Texte", "eBook", "Scan", "Web"],
        done: "Terminé", unplayed: "Non écouté", playing: "Lecture en cours",
        langScreen: "Langue de la voix", langSection: "Langue de la voix (10 langues)",
        voiceSec: "VOIX", voicePick: "Voix", voiceName: "Amélie",
        speed: "Vitesse", pitch: "Hauteur", normalValue: "x1.0 (Normal)",
        slow: "Lent", normal: "Normal 1.0", fast: "Rapide", low: "Grave", high: "Aigu",
        dictSec: "DICTIONNAIRE", userDict: "Dictionnaire perso", dictCount: "12",
        cacheSec: "CACHE", cache: "Cache audio", clear: "Vider",
        supportSec: "ASSISTANCE", contact: "Contact et avis",
        file: "Les Misérables.pdf", chapter: "LIVRE PREMIER", pageLabel: "3 / 12 pages",
        highlight: "la ville de Digne",
        paraA: "Il y a quelques années, un homme entra dans ",
        paraAEnd: ". Il portait à la main un bâton et sur le dos un sac de soldat.",
        paraB: "C’était un homme d’une taille moyenne, trapu et robuste, dans la force de l’âge. Il pouvait avoir quarante-six ou quarante-huit ans.",
        paraC: "Une casquette à visière de cuir rabattue cachait en partie son visage, brûlé par le soleil et le hâle, et ruisselant de sueur.",
        readDone: "Il y a quelques années, un homme entra dans la ville de Digne.",
        nowLead: "C’était un homme d’une taille moyenne, ", nowTail: " et robuste, dans la force de l’âge.",
        nextPara: "Une casquette à visière de cuir rabattue cachait en partie son visage brûlé par le soleil.",
        items: [("Les Misérables.pdf", "4,2 Mo", 35), ("Notes — Chapitre 3", "1 240 mots", 100),
                ("Madame Bovary.epub", "1,1 Mo", 8), ("Scan · 3 pages", "OCR fait", 0),
                ("Wikipédia — Mont Fuji", "3 800 mots", 50)],
        caps: [("Écouter\nplutôt que lire", "Texte, PDF, livres, pages web et scans lus à voix haute"),
               ("Ouvrez un PDF,\nécoutez-le", "Ordre des pages et mise en page respectés"),
               ("La phrase lue\ns’illumine", "Suivez des yeux pendant l’écoute"),
               ("10 langues,\nvoix natives", "Français, anglais, japonais et 7 autres"),
               ("Réglez la vitesse\net la hauteur", "Ajoutez vos prononciations au dictionnaire"),
               ("Arrêtez, reprenez\nquand vous voulez", "Progression et voix mémorisées par fichier")]
    )

    static let it = ShotStrings(
        code: "it",
        navHome: "Narratore", navFiles: "I miei file", navSettings: "Impostazioni",
        tabHome: "Home", tabFiles: "File", tabSettings: "Impost.",
        greeting: "Tutto quello che vuoi leggere, ad alta voce.", recent: "File recenti",
        tileText: "Testo", tileTxt: "File TXT", tileDrive: "Drive",
        tileBook: "Libri", tileScan: "Scansione", tileLink: "Link",
        search: "Cerca file",
        filters: ["Tutti", "PDF", "Testo", "Libri"],
        types: ["PDF", "Testo", "eBook", "Scansione", "Web"],
        done: "Completato", unplayed: "Non ascoltato", playing: "In riproduzione",
        langScreen: "Lingua della voce", langSection: "Lingua della voce (10 lingue)",
        voiceSec: "VOCE", voicePick: "Voce", voiceName: "Alice",
        speed: "Velocità", pitch: "Tono", normalValue: "x1.0 (Normale)",
        slow: "Lenta", normal: "Normale 1.0", fast: "Veloce", low: "Grave", high: "Acuto",
        dictSec: "DIZIONARIO", userDict: "Dizionario personale", dictCount: "12",
        cacheSec: "CACHE", cache: "Cache audio", clear: "Svuota",
        supportSec: "SUPPORTO", contact: "Contatti e feedback",
        file: "La Divina Commedia.pdf", chapter: "CANTO I", pageLabel: "3 / 12 pagine",
        highlight: "una selva oscura",
        paraA: "Nel mezzo del cammin di nostra vita mi ritrovai in ",
        paraAEnd: ", ché la diritta via era smarrita.",
        paraB: "Ahi quanto a dir qual era è cosa dura esta selva selvaggia e aspra e forte che nel pensier rinova la paura!",
        paraC: "Tant’ è amara che poco è più morte; ma per trattar del ben ch’i’ vi trovai, dirò de l’altre cose ch’i’ v’ho scorte.",
        readDone: "Nel mezzo del cammin di nostra vita mi ritrovai in una selva oscura.",
        nowLead: "Ahi quanto a dir qual era è ", nowTail: " esta selva selvaggia e aspra e forte!",
        nextPara: "Tant’ è amara che poco è più morte; ma per trattar del ben ch’i’ vi trovai.",
        items: [("La Divina Commedia.pdf", "4,2 MB", 35), ("Note — Capitolo 3", "1.240 parole", 100),
                ("I Promessi Sposi.epub", "1,1 MB", 8), ("Scansione · 3 pagine", "OCR fatto", 0),
                ("Wikipedia — Monte Fuji", "3.800 parole", 50)],
        caps: [("Ascolta\ninvece di leggere", "Testo, PDF, libri, pagine web e scansioni letti ad alta voce"),
               ("Apri un PDF\ne ascoltalo", "Ordine delle pagine e impaginazione invariati"),
               ("La frase letta\nsi illumina", "Segui con gli occhi mentre ascolti"),
               ("10 lingue,\ncon voce nativa", "Italiano, inglese, giapponese e altre 7"),
               ("Regola velocità\ne tono", "Insegnale le tue pronunce nel dizionario"),
               ("Fermati e riprendi\nquando vuoi", "Avanzamento e voce salvati per ogni file")]
    )

    static let ko = ShotStrings(
        code: "ko",
        navHome: "내레이터", navFiles: "내 파일", navSettings: "설정",
        tabHome: "홈", tabFiles: "내 파일", tabSettings: "설정",
        greeting: "읽고 싶은 것을, 목소리로.", recent: "최근 파일",
        tileText: "텍스트", tileTxt: "TXT 파일", tileDrive: "드라이브",
        tileBook: "책", tileScan: "스캔", tileLink: "링크",
        search: "파일 검색",
        filters: ["전체", "PDF", "텍스트", "책"],
        types: ["PDF", "텍스트", "전자책", "스캔", "웹"],
        done: "완료", unplayed: "재생 안 함", playing: "재생 중",
        langScreen: "읽기 언어", langSection: "음성 언어 (10개 언어)",
        voiceSec: "음성 설정", voicePick: "음성 선택", voiceName: "Yuna",
        speed: "말하기 속도", pitch: "음의 높이", normalValue: "x1.0 (기본)",
        slow: "느리게", normal: "기본 1.0", fast: "빠르게", low: "낮게", high: "높게",
        dictSec: "사전", userDict: "사용자 사전", dictCount: "12개",
        cacheSec: "캐시", cache: "음성 캐시", clear: "지우기",
        supportSec: "지원", contact: "문의 및 피드백",
        file: "운수 좋은 날.pdf", chapter: "1", pageLabel: "3 / 12 페이지",
        highlight: "진눈깨비가",
        paraA: "새침하고 흐린 날씨에 눈이 올 듯하더니 ",
        paraAEnd: " 내리었다. 이 눈은 백성들의 마음을 무겁게 하였다.",
        paraB: "김첨지는 이 날 이상하게도 운수가 좋았다. 아침 댓바람에 손님을 만난 것이다.",
        paraC: "문안에 들어간다는 앞집 마마님을 전찻길까지 모셔다 드린 것을 비롯으로 행운이 계속되었다.",
        readDone: "새침하고 흐린 날씨에 눈이 올 듯하더니 진눈깨비가 내리었다.",
        nowLead: "김첨지는 이 날 ", nowTail: " 운수가 좋았다. 아침 댓바람에 손님을 만난 것이다.",
        nextPara: "문안에 들어간다는 앞집 마마님을 전찻길까지 모셔다 드린 것을 비롯으로 행운이 계속되었다.",
        items: [("운수 좋은 날.pdf", "4.2 MB", 35), ("메모 — 3장", "1,240자", 100),
                ("무정.epub", "1.1 MB", 8), ("스캔 · 3페이지", "OCR 완료", 0),
                ("위키백과 — 후지산", "3,800자", 50)],
        caps: [("읽지 말고,\n들으세요", "텍스트·PDF·책·웹·스캔을 그대로 음성으로"),
               ("PDF도 열면\n바로 음성으로", "지면 레이아웃 그대로, 페이지 순서대로 읽어요"),
               ("지금 읽는 문장이\n빛납니다", "눈으로 따라가며 듣는 하이라이트"),
               ("10개 언어,\n원어민 발음으로", "한국어·영어·일본어 등 10개 언어 지원"),
               ("속도도 높이도\n원하는 대로", "읽는 법은 사용자 사전에 기억시켜요"),
               ("멈춰도\n이어서 들어요", "파일마다 진행률과 음성 설정을 기억")]
    )

    static let th = ShotStrings(
        code: "th",
        navHome: "ผู้บรรยาย", navFiles: "ไฟล์ของฉัน", navSettings: "ตั้งค่า",
        tabHome: "หน้าแรก", tabFiles: "ไฟล์", tabSettings: "ตั้งค่า",
        greeting: "ทุกอย่างที่คุณอยากอ่าน ให้เสียงอ่านให้", recent: "ไฟล์ล่าสุด",
        tileText: "ข้อความ", tileTxt: "ไฟล์ TXT", tileDrive: "ไดรฟ์",
        tileBook: "หนังสือ", tileScan: "สแกน", tileLink: "ลิงก์",
        search: "ค้นหาไฟล์",
        filters: ["ทั้งหมด", "PDF", "ข้อความ", "หนังสือ"],
        types: ["PDF", "ข้อความ", "eBook", "สแกน", "เว็บ"],
        done: "เสร็จแล้ว", unplayed: "ยังไม่ได้ฟัง", playing: "กำลังเล่น",
        langScreen: "ภาษาของเสียง", langSection: "ภาษาของเสียง (10 ภาษา)",
        voiceSec: "เสียง", voicePick: "เลือกเสียง", voiceName: "Kanya",
        speed: "ความเร็ว", pitch: "ระดับเสียง", normalValue: "x1.0 (ปกติ)",
        slow: "ช้า", normal: "ปกติ 1.0", fast: "เร็ว", low: "ต่ำ", high: "สูง",
        dictSec: "พจนานุกรม", userDict: "พจนานุกรมของฉัน", dictCount: "12 คำ",
        cacheSec: "แคช", cache: "แคชเสียง", clear: "ล้าง",
        supportSec: "ช่วยเหลือ", contact: "ติดต่อและข้อเสนอแนะ",
        file: "พระอภัยมณี.pdf", chapter: "ตอนที่ ๑", pageLabel: "3 / 12 หน้า",
        highlight: "ดังกังวาน",
        paraA: "เสียงปี่ของพระอภัยมณี",
        paraAEnd: "ไปทั่วท้องทะเล ผู้คนที่ได้ฟังก็หยุดฟังด้วยความประหลาดใจ",
        paraB: "สุนทรภู่เล่าเรื่องนี้ไว้เป็นกลอนสุภาพ อ่านออกเสียงได้ไพเราะทั้งเรื่อง",
        paraC: "บทกลอนไทยเมื่ออ่านออกเสียงจะได้จังหวะและสัมผัสที่ครบถ้วน เหมาะกับการฟังมากกว่าการอ่านเงียบ",
        readDone: "เสียงปี่ของพระอภัยมณีดังกังวานไปทั่วท้องทะเล",
        nowLead: "สุนทรภู่เล่าเรื่องนี้ไว้", nowTail: "เป็นกลอนสุภาพ อ่านออกเสียงได้ไพเราะทั้งเรื่อง",
        nextPara: "บทกลอนไทยเมื่ออ่านออกเสียงจะได้จังหวะและสัมผัสที่ครบถ้วน",
        items: [("พระอภัยมณี.pdf", "4.2 MB", 35), ("บันทึก — บทที่ 3", "1,240 คำ", 100),
                ("ขุนช้างขุนแผน.epub", "1.1 MB", 8), ("สแกน · 3 หน้า", "OCR แล้ว", 0),
                ("วิกิพีเดีย — ภูเขาไฟฟูจิ", "3,800 คำ", 50)],
        caps: [("ฟัง\nแทนการอ่าน", "ข้อความ PDF หนังสือ เว็บ และสแกน อ่านออกเสียงได้ทันที"),
               ("เปิด PDF\nแล้วฟังได้เลย", "คงลำดับหน้าและการจัดหน้าไว้เหมือนต้นฉบับ"),
               ("ประโยคที่กำลังอ่าน\nจะสว่างขึ้น", "ตามอ่านด้วยตาไปพร้อมกับการฟัง"),
               ("10 ภาษา\nด้วยเสียงเจ้าของภาษา", "ไทย อังกฤษ ญี่ปุ่น และอีก 7 ภาษา"),
               ("ปรับความเร็ว\nและระดับเสียงได้", "สอนคำอ่านเองได้ในพจนานุกรม"),
               ("หยุดตอนไหน\nก็ต่อได้", "จำความคืบหน้าและเสียงของแต่ละไฟล์")]
    )

    static let tr = ShotStrings(
        code: "tr",
        navHome: "Anlatıcı", navFiles: "Dosyalarım", navSettings: "Ayarlar",
        tabHome: "Ana sayfa", tabFiles: "Dosyalar", tabSettings: "Ayarlar",
        greeting: "Okumak istediğin her şey, sesli.", recent: "Son dosyalar",
        tileText: "Metin", tileTxt: "TXT dosyası", tileDrive: "Drive",
        tileBook: "Kitaplar", tileScan: "Tarama", tileLink: "Bağlantı",
        search: "Dosya ara",
        filters: ["Tümü", "PDF", "Metin", "Kitaplar"],
        types: ["PDF", "Metin", "e-Kitap", "Tarama", "Web"],
        done: "Bitti", unplayed: "Dinlenmedi", playing: "Çalıyor",
        langScreen: "Ses dili", langSection: "Ses dili (10 dil)",
        voiceSec: "SES", voicePick: "Ses seçimi", voiceName: "Yelda",
        speed: "Hız", pitch: "Perde", normalValue: "x1.0 (Normal)",
        slow: "Yavaş", normal: "Normal 1.0", fast: "Hızlı", low: "Kalın", high: "İnce",
        dictSec: "SÖZLÜK", userDict: "Kendi sözlüğüm", dictCount: "12",
        cacheSec: "ÖNBELLEK", cache: "Ses önbelleği", clear: "Temizle",
        supportSec: "DESTEK", contact: "İletişim ve geri bildirim",
        file: "Çalıkuşu.pdf", chapter: "BİRİNCİ KISIM", pageLabel: "3 / 12 sayfa",
        highlight: "bir defter gibi",
        paraA: "Feride, hayatını ",
        paraAEnd: " yazmaya başladı. Her akşam bir sayfa, her sayfada bir gün vardı.",
        paraB: "Yazdıkça hatırlıyor, hatırladıkça yazıyordu. Defterin sayfaları çabuk doldu.",
        paraC: "Yıllar sonra o defteri açtığında, satırların arasında kendi sesini duyacaktı.",
        readDone: "Feride, hayatını bir defter gibi yazmaya başladı.",
        nowLead: "Yazdıkça hatırlıyor, ", nowTail: "hatırladıkça yazıyordu. Defterin sayfaları çabuk doldu.",
        nextPara: "Yıllar sonra o defteri açtığında, satırların arasında kendi sesini duyacaktı.",
        items: [("Çalıkuşu.pdf", "4,2 MB", 35), ("Notlar — 3. Bölüm", "1.240 kelime", 100),
                ("Kuyucaklı Yusuf.epub", "1,1 MB", 8), ("Tarama · 3 sayfa", "OCR bitti", 0),
                ("Vikipedi — Fuji Dağı", "3.800 kelime", 50)],
        caps: [("Okumak yerine\ndinle", "Metin, PDF, kitap, web ve taramalar sesli okunur"),
               ("PDF’i aç,\nhemen dinle", "Sayfa sırası ve düzeni olduğu gibi korunur"),
               ("Okunan cümle\nvurgulanır", "Dinlerken gözünle takip et"),
               ("10 dil,\nyerel telaffuzla", "Türkçe, İngilizce, Japonca ve 7 dil daha"),
               ("Hızı ve perdeyi\nsen ayarla", "Kendi okunuşlarını sözlüğe öğret"),
               ("Nerede bıraktıysan\noradan devam", "İlerleme ve ses ayarı dosya başına saklanır")]
    )

    static let vi = ShotStrings(
        code: "vi",
        navHome: "Người đọc", navFiles: "Tệp của tôi", navSettings: "Cài đặt",
        tabHome: "Trang chủ", tabFiles: "Tệp", tabSettings: "Cài đặt",
        greeting: "Mọi thứ bạn muốn đọc, được đọc thành tiếng.", recent: "Tệp gần đây",
        tileText: "Văn bản", tileTxt: "Tệp TXT", tileDrive: "Drive",
        tileBook: "Sách", tileScan: "Quét", tileLink: "Liên kết",
        search: "Tìm tệp",
        filters: ["Tất cả", "PDF", "Văn bản", "Sách"],
        types: ["PDF", "Văn bản", "eBook", "Bản quét", "Web"],
        done: "Đã xong", unplayed: "Chưa nghe", playing: "Đang phát",
        langScreen: "Ngôn ngữ giọng đọc", langSection: "Ngôn ngữ giọng đọc (10 ngôn ngữ)",
        voiceSec: "GIỌNG ĐỌC", voicePick: "Chọn giọng", voiceName: "Linh",
        speed: "Tốc độ", pitch: "Cao độ", normalValue: "x1.0 (Bình thường)",
        slow: "Chậm", normal: "Chuẩn 1.0", fast: "Nhanh", low: "Thấp", high: "Cao",
        dictSec: "TỪ ĐIỂN", userDict: "Từ điển của tôi", dictCount: "12",
        cacheSec: "BỘ NHỚ ĐỆM", cache: "Bộ đệm âm thanh", clear: "Xoá",
        supportSec: "HỖ TRỢ", contact: "Liên hệ và góp ý",
        file: "Truyện Kiều.pdf", chapter: "PHẦN I", pageLabel: "3 / 12 trang",
        highlight: "chữ tài chữ mệnh",
        paraA: "Trăm năm trong cõi người ta, ",
        paraAEnd: " khéo là ghét nhau. Trải qua một cuộc bể dâu, những điều trông thấy mà đau đớn lòng.",
        paraB: "Lạ gì bỉ sắc tư phong, trời xanh quen thói má hồng đánh ghen.",
        paraC: "Cảo thơm lần trước đèn khuya, phong tình cổ lục còn truyền sử xanh.",
        readDone: "Trăm năm trong cõi người ta, chữ tài chữ mệnh khéo là ghét nhau.",
        nowLead: "Lạ gì bỉ sắc tư phong, ", nowTail: "trời xanh quen thói má hồng đánh ghen.",
        nextPara: "Cảo thơm lần trước đèn khuya, phong tình cổ lục còn truyền sử xanh.",
        items: [("Truyện Kiều.pdf", "4,2 MB", 35), ("Ghi chú — Chương 3", "1.240 từ", 100),
                ("Số đỏ.epub", "1,1 MB", 8), ("Bản quét · 3 trang", "Đã OCR", 0),
                ("Wikipedia — Núi Phú Sĩ", "3.800 từ", 50)],
        caps: [("Nghe\nthay vì đọc", "Văn bản, PDF, sách, web và bản quét đều đọc thành tiếng"),
               ("Mở PDF là\nnghe được ngay", "Giữ nguyên thứ tự và cách dàn trang"),
               ("Câu đang đọc\nsẽ sáng lên", "Vừa nghe vừa dõi theo bằng mắt"),
               ("10 ngôn ngữ,\nphát âm bản ngữ", "Tiếng Việt, Anh, Nhật và 7 ngôn ngữ khác"),
               ("Tuỳ chỉnh tốc độ\nvà cao độ", "Dạy cách đọc riêng bằng từ điển"),
               ("Dừng ở đâu,\ntiếp ở đó", "Ghi nhớ tiến độ và giọng đọc cho từng tệp")]
    )
}

// MARK: - 対応言語リスト（04 言語画面で使用）

private struct ShotLang { let code: String, name: String, sample: String }

private let shotLangs: [ShotLang] = [
    .init(code: "ja-JP", name: "日本語", sample: "吾輩は猫である。名前はまだ無い。"),
    .init(code: "en-US", name: "English", sample: "Alice was beginning to get very tired of sitting by her sister."),
    .init(code: "de-DE", name: "Deutsch", sample: "Als Gregor Samsa eines Morgens aus unruhigen Träumen erwachte."),
    .init(code: "es-ES", name: "Español", sample: "En un lugar de la Mancha, de cuyo nombre no quiero acordarme."),
    .init(code: "fr-FR", name: "Français", sample: "Il y a quelques années, un homme entra dans la ville de Digne."),
    .init(code: "it-IT", name: "Italiano", sample: "Nel mezzo del cammin di nostra vita."),
    .init(code: "ko-KR", name: "한국어", sample: "새침하고 흐린 날씨에 눈이 올 듯하더니 진눈깨비가 내리었다."),
    .init(code: "th-TH", name: "ไทย", sample: "เสียงปี่ของพระอภัยมณีดังกังวานทั่วท้องทะเล"),
    .init(code: "tr-TR", name: "Türkçe", sample: "Feride, hayatını bir defter gibi yazmaya başladı."),
    .init(code: "vi-VN", name: "Tiếng Việt", sample: "Trăm năm trong cõi người ta, chữ tài chữ mệnh khéo là ghét nhau.")
]

// MARK: - 端末シャーシ

/// ステータスバー。実機のスクショに必ず写るので省略しない（リアリティの差が一番大きい）。
private struct ShotStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 17, weight: .semibold))
            Spacer()
            HStack(alignment: .bottom, spacing: 6) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach([5, 8, 11, 14], id: \.self) { h in
                        Capsule().fill(Color.black).frame(width: 3, height: CGFloat(h))
                    }
                }
                Image(systemName: "wifi").font(.system(size: 14, weight: .medium))
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                        .frame(width: 22, height: 11)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.black).frame(width: 16, height: 7).padding(.leading, 1.5)
                        }
                    Capsule().fill(Color.black.opacity(0.4)).frame(width: 1.5, height: 4)
                }
            }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 32)
        .padding(.bottom, 8)
        .frame(height: 54, alignment: .bottom)
        .background(Color.white)
    }
}

/// 実機と同じ 3 タブ。旧案はタブバーごと省いていたため「実機と違う」印象が強かった。
private struct ShotTabBar: View {
    let s: ShotStrings
    let active: Int

    var body: some View {
        HStack(spacing: 0) {
            item("house", s.tabHome, 0)
            item("doc", s.tabFiles, 1)
            item("gear", s.tabSettings, 2)
        }
        .padding(.top, 7)
        .frame(height: 83, alignment: .top)
        .background(Color(white: 0.976).opacity(0.94))
        .overlay(Rectangle().fill(ShotTheme.separator).frame(height: 0.5), alignment: .top)
    }

    private func item(_ icon: String, _ label: String, _ idx: Int) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 22))
            Text(label).font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(idx == active ? ShotTheme.accent : ShotTheme.secondary)
        .frame(maxWidth: .infinity)
    }
}

/// 端末フレーム。**中身は実機の論理サイズ（iPhone 430×932 / iPad 1024×1366）で組み、
/// フレームに合わせて縮小して貼る。** こうしないとフォントだけが相対的に巨大になり、
/// 「実機と違うモック」に見える。
private struct ShotDeviceFrame<Content: View>: View {
    let isPad: Bool
    @ViewBuilder let content: () -> Content

    private var screenSize: CGSize { isPad ? CGSize(width: 1024, height: 1366) : CGSize(width: 430, height: 932) }

    var body: some View {
        GeometryReader { geo in
            let bezel: CGFloat = isPad ? 12 : 9
            let k = min((geo.size.height - bezel * 2) / screenSize.height,
                        (geo.size.width - bezel * 2) / screenSize.width)
            let innerW = screenSize.width * k
            let innerH = screenSize.height * k
            let frameW = innerW + bezel * 2
            let frameH = innerH + bezel * 2
            let outerCR: CGFloat = isPad ? 42 : frameW * 0.125

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: outerCR).fill(Color.black)
                    .shadow(color: .black.opacity(0.28), radius: 20, y: 12)

                // scaleEffect はレイアウトサイズを変えないので、子は 430×932 のまま
                // innerW×innerH（より小さい）の中央に置かれる。ここで anchor を
                // .topLeading にすると拡縮の原点が枠外（負の座標）になり、中身が
                // 左上へずれて左端と下端が切れる。中央基準なら視覚と枠が一致する。
                content()
                    .frame(width: screenSize.width, height: screenSize.height)
                    .scaleEffect(k)
                    .frame(width: innerW, height: innerH)
                    .clipShape(RoundedRectangle(cornerRadius: max(outerCR - bezel, 8)))
                    .padding(bezel)

                if !isPad {
                    Capsule().fill(Color.black)
                        .frame(width: innerW * 0.31, height: 26)
                        .padding(.top, bezel + 11)
                }
            }
            .frame(width: frameW, height: frameH)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

/// 見出し + 端末フレーム。高さは明示計算して固定する（#125 と同じ理由）。
struct ShotCanvas<Content: View>: View {
    let caption: String
    let subtitle: String
    let isPad: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let headerH: CGFloat = 210
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(caption)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                    Text(subtitle)
                        .font(.system(size: 16, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(ShotTheme.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 36)
                .padding(.top, 44)
                .frame(width: geo.size.width, height: headerH, alignment: .top)

                ShotDeviceFrame(isPad: isPad, content: content)
                    .frame(width: geo.size.width, height: geo.size.height - headerH - 30)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(ShotTheme.canvas)
    }
}

// MARK: - 01 ホーム

private struct ShotHome: View {
    let s: ShotStrings

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()
            VStack(alignment: .leading, spacing: 0) {
                Text(s.navHome)
                    .font(.system(size: 34, weight: .bold)).padding(.horizontal, 20).padding(.top, 6)
                Text(s.greeting)
                    .font(.system(size: 15)).foregroundColor(ShotTheme.secondary)
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 14)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    tile("doc.text.fill", s.tileText)
                    tile("doc.richtext.fill", "PDF")
                    tile("doc.plaintext.fill", s.tileTxt)
                    tile("externaldrive.fill", s.tileDrive)
                    tile("books.vertical.fill", s.tileBook)
                    tile("camera.fill", s.tileScan)
                    tile("link", s.tileLink)
                }
                .padding(.horizontal, 20)

                Text(s.recent)
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 10)

                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        ShotFileRow(s: s, index: i, showsProgressBar: false)
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
            }
            .background(ShotTheme.canvas)
            ShotTabBar(s: s, active: 0)
        }
        .background(Color.white)
    }

    private func tile(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26)).foregroundColor(ShotTheme.accent)
                .frame(width: 52, height: 52)
                .background(ShotTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity).frame(height: 96)
        .background(ShotTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

/// ホーム / マイファイル共通の 1 行。進捗バーとメタ情報で「使い込まれている」感を出す。
private struct ShotFileRow: View {
    let s: ShotStrings
    let index: Int
    let showsProgressBar: Bool

    private var icons: [String] { ["doc.richtext.fill", "doc.text.fill", "books.vertical.fill", "camera.fill", "link"] }
    private var ago: [String] { ["1", "3", "7", "14", "30"] }   // 表示は下の meta で組む

    var body: some View {
        let item = s.items[index]
        HStack(spacing: 12) {
            Image(systemName: icons[index])
                .font(.system(size: 18)).foregroundColor(ShotTheme.accent)
                .frame(width: 40, height: 40)
                .background(ShotTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.0).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                if showsProgressBar {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ShotTheme.accentSoft).frame(height: 4)
                            Capsule().fill(ShotTheme.accent)
                                .frame(width: geo.size.width * CGFloat(item.2) / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                Text(meta(index)).font(.system(size: 12)).foregroundColor(ShotTheme.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill").font(.system(size: 26)).foregroundColor(ShotTheme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(ShotTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: showsProgressBar ? 14 : 12))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    /// 「種別 · サイズ · 進捗 · 相対日付」。相対日付はロケール依存なので
    /// 文字列テーブルに持たず RelativeDateTimeFormatter に任せる。
    private func meta(_ i: Int) -> String {
        let item = s.items[i]
        let progress = item.2 == 100 ? s.done : (item.2 == 0 ? s.unplayed : "\(item.2)%")
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        let days: [TimeInterval] = [-86400, -3 * 86400, -7 * 86400, -14 * 86400, -30 * 86400]
        let when = f.localizedString(fromTimeInterval: days[i])
        return "\(s.types[i]) · \(item.1) · \(progress) · \(when)"
    }
}

// MARK: - 02 PDF（紙面レイアウト）

private struct ShotPDF: View {
    let s: ShotStrings

    /// 紙面の第1段落。読み上げ中の範囲を背景色つきで示す。
    /// `Text(a) + Text(b).foregroundColor(.white)` の連結では**背景色を付けられず**、
    /// 白い紙面に白文字を置くことになって文字が消える。03 ハイライトと同じく
    /// AttributedString でインラインに背景色と文字色を指定する。
    /// フォントは指定しない（Text 側の明朝を継承させる）。
    private var page: AttributedString {
        var text = AttributedString(s.paraA + s.highlight + s.paraAEnd)
        if let r = text.range(of: s.highlight) {
            text[r].backgroundColor = ShotTheme.accent
            text[r].foregroundColor = Color.white
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()

            HStack(spacing: 12) {
                Image(systemName: "chevron.left").font(.title2).foregroundColor(ShotTheme.accent)
                Text(s.file).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity)
                Image(systemName: "square.and.arrow.up").font(.title3).foregroundColor(ShotTheme.accent)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            .background(Color.white)
            .overlay(Rectangle().fill(ShotTheme.separator).frame(height: 0.5), alignment: .bottom)

            // 白紙のスクロールビューではなく「紙」を描く。ページ番号と余白があるだけで
            // PDF を読み上げている画面だと一目で伝わる。
            VStack(alignment: .leading, spacing: 14) {
                Text(s.chapter)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(ShotTheme.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(page)
                    .font(.custom("HiraMinProN-W3", size: 15.5))
                    .lineSpacing(7)
                Text(s.paraB).font(.custom("HiraMinProN-W3", size: 15.5)).lineSpacing(7)
                Text(s.paraC).font(.custom("HiraMinProN-W3", size: 15.5)).lineSpacing(7)
                    .foregroundColor(ShotTheme.secondary)
                Spacer(minLength: 0)
                Text("3").font(.system(size: 12)).foregroundColor(ShotTheme.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 30).padding(.vertical, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
            .padding(18)
            .background(Color(white: 0.89))

            ShotPlayerBar(s: s, progress: 0.26, showsTime: true)
        }
        .background(ShotTheme.grouped)
    }
}

/// 再生バー。経過 / 残り時間とページ表示を入れて「いま鳴っている」状態にする。
private struct ShotPlayerBar: View {
    let s: ShotStrings
    let progress: CGFloat
    let showsTime: Bool

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ShotTheme.separator).frame(height: 4)
                    Capsule().fill(ShotTheme.accent).frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            if showsTime {
                HStack {
                    Text("4:12"); Spacer(); Text(s.pageLabel); Spacer(); Text("-11:48")
                }
                .font(.system(size: 11)).foregroundColor(ShotTheme.secondary).padding(.top, 7)
            }

            HStack(spacing: 34) {
                Image(systemName: "gobackward.15").font(.title2)
                Image(systemName: "pause.circle.fill").font(.system(size: 66)).foregroundColor(ShotTheme.accent)
                Image(systemName: "goforward.15").font(.title2)
            }
            .foregroundColor(ShotTheme.label)
            .padding(.top, 12)

            Text("x1.0")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(ShotTheme.secondary)
                .padding(.top, 10)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
        .background(Color.white)
        .overlay(Rectangle().fill(ShotTheme.separator).frame(height: 0.5), alignment: .top)
    }
}

// MARK: - 03 ハイライト

private struct ShotHighlight: View {
    let s: ShotStrings

    private var active: AttributedString {
        var text = AttributedString(s.nowLead + s.highlight + s.nowTail)
        if let r = text.range(of: s.highlight) {
            text[r].backgroundColor = ShotTheme.accent
            text[r].foregroundColor = Color.white
            text[r].font = .system(size: 19, weight: .bold)
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform").font(.title2).foregroundColor(ShotTheme.accent)
                    Text("Voice Narrator").font(.system(size: 26, weight: .bold))
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach([8, 15, 11, 19, 13], id: \.self) { h in
                        Capsule().fill(ShotTheme.accent).frame(width: 3, height: CGFloat(h))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
            .background(Color.white)

            VStack(alignment: .leading, spacing: 14) {
                Text(s.readDone).font(.system(size: 16)).foregroundColor(ShotTheme.secondary).lineSpacing(5)

                HStack(spacing: 0) {
                    Rectangle().fill(ShotTheme.accent).frame(width: 3).cornerRadius(1.5)
                    Text(active).font(.system(size: 19)).lineSpacing(7)
                        .padding(.leading, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(ShotTheme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(s.nextPara).font(.system(size: 16)).foregroundColor(ShotTheme.tertiary).lineSpacing(5)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)

            ShotPlayerBar(s: s, progress: 0.38, showsTime: false)
        }
        .background(Color.white)
    }
}

// MARK: - 04 言語

private struct ShotLanguages: View {
    let s: ShotStrings

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()

            HStack {
                Image(systemName: "chevron.left").font(.title2).foregroundColor(ShotTheme.accent)
                Text(s.langScreen).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity)
                Image(systemName: "chevron.left").font(.title2).opacity(0)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            .background(Color.white)
            .overlay(Rectangle().fill(ShotTheme.separator).frame(height: 0.5), alignment: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(s.langSection).font(.system(size: 13)).foregroundColor(ShotTheme.secondary)
                    .padding(.horizontal, 16)

                // 選択済みはそのスクショの言語の行。固定インデックスにすると
                // 「見出しはタイ語なのに音声は日本語が選択済み」になってしまう。
                let selected = shotLangs.firstIndex { $0.code.hasPrefix(s.code + "-") } ?? 0

                VStack(spacing: 0) {
                    ForEach(Array(shotLangs.enumerated()), id: \.offset) { idx, lang in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 7) {
                                    Text(lang.name).font(.system(size: 16, weight: .semibold))
                                    Text(lang.code).font(.system(size: 12)).foregroundColor(ShotTheme.tertiary)
                                }
                                Text(lang.sample).font(.system(size: 12.5))
                                    .foregroundColor(ShotTheme.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if idx == selected {
                                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                                    .foregroundColor(ShotTheme.accent)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        if idx < shotLangs.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(ShotTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ShotTheme.grouped)
        }
        .background(ShotTheme.grouped)
    }
}

// MARK: - 05 音声設定

/// UISlider は ImageRenderer で描画できないため純 SwiftUI で描き直す（既存 MockSlider と同趣旨）。
private struct ShotSlider: View {
    let value: CGFloat

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 20
            let travel = max(geo.size.width - knob, 0)
            ZStack(alignment: .leading) {
                Capsule().fill(ShotTheme.separator).frame(height: 4)
                Capsule().fill(ShotTheme.accent).frame(width: knob / 2 + travel * value, height: 4)
                Circle().fill(.white).frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .offset(x: travel * value)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
    }
}

private struct ShotSettings: View {
    let s: ShotStrings

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()

            Text(s.navSettings)
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 10)
                .background(ShotTheme.grouped)

            VStack(alignment: .leading, spacing: 8) {
                section(s.voiceSec)
                VStack(spacing: 0) {
                    HStack {
                        Text(s.voicePick).font(.system(size: 16))
                        Spacer()
                        Text(s.voiceName).font(.system(size: 16)).foregroundColor(ShotTheme.secondary)
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(ShotTheme.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    Divider().padding(.leading, 16)
                    slider(title: s.speed, value: s.normalValue, v: 0.52,
                           left: "tortoise.fill", right: "hare.fill",
                           labels: (s.slow, s.normal, s.fast))
                    Divider().padding(.leading, 16)
                    slider(title: s.pitch, value: "x1.2", v: 0.46,
                           left: "speaker.wave.1.fill", right: "speaker.wave.3.fill",
                           labels: (s.low, s.normal, s.high))
                }
                .background(ShotTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                section(s.dictSec)
                row("character.book.closed.fill", s.userDict, trailing: s.dictCount)
                section(s.cacheSec)
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive").foregroundColor(ShotTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.cache).font(.system(size: 16))
                        Text("48.2 MB").font(.system(size: 12)).foregroundColor(ShotTheme.secondary)
                    }
                    Spacer()
                    Text(s.clear).font(.system(size: 16)).foregroundColor(ShotTheme.destructive)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(ShotTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                section(s.supportSec)
                row("envelope.fill", s.contact, trailing: nil)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ShotTheme.grouped)

            ShotTabBar(s: s, active: 2)
        }
        .background(ShotTheme.grouped)
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 13)).foregroundColor(ShotTheme.secondary)
            .padding(.horizontal, 16).padding(.top, 8)
    }

    private func row(_ icon: String, _ title: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(ShotTheme.accent)
            Text(title).font(.system(size: 16))
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 15)).foregroundColor(ShotTheme.secondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(ShotTheme.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(ShotTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func slider(title: String, value: String, v: CGFloat,
                        left: String, right: String,
                        labels: (String, String, String)) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(value).font(.system(size: 16, design: .monospaced)).foregroundColor(ShotTheme.accent)
            }
            HStack(spacing: 12) {
                Image(systemName: left).foregroundColor(ShotTheme.secondary)
                ShotSlider(value: v)
                Image(systemName: right).foregroundColor(ShotTheme.secondary)
            }
            HStack {
                Text(labels.0); Spacer(); Text(labels.1); Spacer(); Text(labels.2)
            }
            .font(.system(size: 12)).foregroundColor(ShotTheme.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - 06 マイファイル

private struct ShotMyFiles: View {
    let s: ShotStrings

    var body: some View {
        VStack(spacing: 0) {
            ShotStatusBar()

            HStack(alignment: .bottom) {
                Text(s.navFiles).font(.system(size: 34, weight: .bold))
                Spacer()
                Image(systemName: "trash").font(.system(size: 20)).foregroundColor(ShotTheme.accent)
                    .padding(.bottom, 5)
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 10)
            .background(Color.white)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(ShotTheme.secondary)
                Text(s.search).foregroundColor(ShotTheme.secondary)
                Spacer()
            }
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(white: 0.937))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            // 実機は .pickerStyle(.segmented)。旧案のピル型チップは実装と食い違っていた。
            HStack(spacing: 2) {
                ForEach(Array(s.filters.enumerated()), id: \.offset) { idx, f in
                    Text(f)
                        .font(.system(size: 13, weight: idx == 0 ? .semibold : .regular))
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(idx == 0 ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .shadow(color: .black.opacity(idx == 0 ? 0.12 : 0), radius: 2, y: 1)
                }
            }
            .padding(2)
            .background(Color(white: 0.55).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 16).padding(.vertical, 10)

            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { i in
                    ShotFileRow(s: s, index: i, showsProgressBar: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // 再生中ミニプレイヤー（MiniPlayerView 相当）。実機ではタブバーの上に浮く。
            HStack(spacing: 12) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 17)).foregroundColor(ShotTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(ShotTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.file).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach([5, 9, 6, 10], id: \.self) { h in
                                Capsule().fill(ShotTheme.accent).frame(width: 2, height: CGFloat(h))
                            }
                        }
                        Text(s.playing).font(.system(size: 11)).foregroundColor(ShotTheme.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "pause.circle.fill").font(.system(size: 32)).foregroundColor(ShotTheme.accent)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(ShotTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.1), radius: 6, y: -1)
            .padding(.horizontal, 12).padding(.bottom, 6)

            ShotTabBar(s: s, active: 1)
        }
        .background(Color.white)
    }
}

// MARK: - 1 枚を組み立てるエントリポイント

/// index: 0 ホーム / 1 PDF / 2 ハイライト / 3 言語 / 4 音声設定 / 5 マイファイル
struct Shot: View {
    let s: ShotStrings
    let index: Int
    var isPad: Bool = false

    var body: some View {
        ShotCanvas(caption: s.caps[index].0, subtitle: s.caps[index].1, isPad: isPad) {
            switch index {
            case 0: ShotHome(s: s)
            case 1: ShotPDF(s: s)
            case 2: ShotHighlight(s: s)
            case 3: ShotLanguages(s: s)
            case 4: ShotSettings(s: s)
            default: ShotMyFiles(s: s)
            }
        }
    }
}

// MARK: - Previews（fastlane で書き出す単位）
// iPhone 6.7": 430 × 932 pt → 1290 × 2796 px
// iPad Pro 12.9": 512 × 683 pt @4x → 2048 × 2732 px

// ── iPhone 6.7"（60枚）
#Preview("📱 JA 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 0).environment(\.locale, .init(identifier: "ja")) }
#Preview("📱 JA 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 1).environment(\.locale, .init(identifier: "ja")) }
#Preview("📱 JA 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 2).environment(\.locale, .init(identifier: "ja")) }
#Preview("📱 JA 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 3).environment(\.locale, .init(identifier: "ja")) }
#Preview("📱 JA 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 4).environment(\.locale, .init(identifier: "ja")) }
#Preview("📱 JA 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ja, index: 5).environment(\.locale, .init(identifier: "ja")) }

#Preview("📱 EN 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 0).environment(\.locale, .init(identifier: "en")) }
#Preview("📱 EN 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 1).environment(\.locale, .init(identifier: "en")) }
#Preview("📱 EN 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 2).environment(\.locale, .init(identifier: "en")) }
#Preview("📱 EN 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 3).environment(\.locale, .init(identifier: "en")) }
#Preview("📱 EN 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 4).environment(\.locale, .init(identifier: "en")) }
#Preview("📱 EN 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .en, index: 5).environment(\.locale, .init(identifier: "en")) }

#Preview("📱 DE 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 0).environment(\.locale, .init(identifier: "de")) }
#Preview("📱 DE 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 1).environment(\.locale, .init(identifier: "de")) }
#Preview("📱 DE 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 2).environment(\.locale, .init(identifier: "de")) }
#Preview("📱 DE 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 3).environment(\.locale, .init(identifier: "de")) }
#Preview("📱 DE 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 4).environment(\.locale, .init(identifier: "de")) }
#Preview("📱 DE 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .de, index: 5).environment(\.locale, .init(identifier: "de")) }

#Preview("📱 ES 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 0).environment(\.locale, .init(identifier: "es")) }
#Preview("📱 ES 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 1).environment(\.locale, .init(identifier: "es")) }
#Preview("📱 ES 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 2).environment(\.locale, .init(identifier: "es")) }
#Preview("📱 ES 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 3).environment(\.locale, .init(identifier: "es")) }
#Preview("📱 ES 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 4).environment(\.locale, .init(identifier: "es")) }
#Preview("📱 ES 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .es, index: 5).environment(\.locale, .init(identifier: "es")) }

#Preview("📱 FR 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 0).environment(\.locale, .init(identifier: "fr")) }
#Preview("📱 FR 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 1).environment(\.locale, .init(identifier: "fr")) }
#Preview("📱 FR 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 2).environment(\.locale, .init(identifier: "fr")) }
#Preview("📱 FR 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 3).environment(\.locale, .init(identifier: "fr")) }
#Preview("📱 FR 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 4).environment(\.locale, .init(identifier: "fr")) }
#Preview("📱 FR 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .fr, index: 5).environment(\.locale, .init(identifier: "fr")) }

#Preview("📱 IT 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 0).environment(\.locale, .init(identifier: "it")) }
#Preview("📱 IT 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 1).environment(\.locale, .init(identifier: "it")) }
#Preview("📱 IT 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 2).environment(\.locale, .init(identifier: "it")) }
#Preview("📱 IT 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 3).environment(\.locale, .init(identifier: "it")) }
#Preview("📱 IT 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 4).environment(\.locale, .init(identifier: "it")) }
#Preview("📱 IT 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .it, index: 5).environment(\.locale, .init(identifier: "it")) }

#Preview("📱 KO 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 0).environment(\.locale, .init(identifier: "ko")) }
#Preview("📱 KO 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 1).environment(\.locale, .init(identifier: "ko")) }
#Preview("📱 KO 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 2).environment(\.locale, .init(identifier: "ko")) }
#Preview("📱 KO 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 3).environment(\.locale, .init(identifier: "ko")) }
#Preview("📱 KO 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 4).environment(\.locale, .init(identifier: "ko")) }
#Preview("📱 KO 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .ko, index: 5).environment(\.locale, .init(identifier: "ko")) }

#Preview("📱 TH 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 0).environment(\.locale, .init(identifier: "th")) }
#Preview("📱 TH 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 1).environment(\.locale, .init(identifier: "th")) }
#Preview("📱 TH 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 2).environment(\.locale, .init(identifier: "th")) }
#Preview("📱 TH 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 3).environment(\.locale, .init(identifier: "th")) }
#Preview("📱 TH 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 4).environment(\.locale, .init(identifier: "th")) }
#Preview("📱 TH 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .th, index: 5).environment(\.locale, .init(identifier: "th")) }

#Preview("📱 TR 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 0).environment(\.locale, .init(identifier: "tr")) }
#Preview("📱 TR 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 1).environment(\.locale, .init(identifier: "tr")) }
#Preview("📱 TR 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 2).environment(\.locale, .init(identifier: "tr")) }
#Preview("📱 TR 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 3).environment(\.locale, .init(identifier: "tr")) }
#Preview("📱 TR 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 4).environment(\.locale, .init(identifier: "tr")) }
#Preview("📱 TR 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .tr, index: 5).environment(\.locale, .init(identifier: "tr")) }

#Preview("📱 VI 01 Home", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 0).environment(\.locale, .init(identifier: "vi")) }
#Preview("📱 VI 02 PDF", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 1).environment(\.locale, .init(identifier: "vi")) }
#Preview("📱 VI 03 Highlight", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 2).environment(\.locale, .init(identifier: "vi")) }
#Preview("📱 VI 04 Languages", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 3).environment(\.locale, .init(identifier: "vi")) }
#Preview("📱 VI 05 Voice", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 4).environment(\.locale, .init(identifier: "vi")) }
#Preview("📱 VI 06 MyFiles", traits: .fixedLayout(width: 430, height: 932)) { Shot(s: .vi, index: 5).environment(\.locale, .init(identifier: "vi")) }

// ── iPad Pro 12.9"（60枚）
#Preview("💻 JA 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 0, isPad: true).environment(\.locale, .init(identifier: "ja")) }
#Preview("💻 JA 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 1, isPad: true).environment(\.locale, .init(identifier: "ja")) }
#Preview("💻 JA 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 2, isPad: true).environment(\.locale, .init(identifier: "ja")) }
#Preview("💻 JA 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 3, isPad: true).environment(\.locale, .init(identifier: "ja")) }
#Preview("💻 JA 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 4, isPad: true).environment(\.locale, .init(identifier: "ja")) }
#Preview("💻 JA 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ja, index: 5, isPad: true).environment(\.locale, .init(identifier: "ja")) }

#Preview("💻 EN 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 0, isPad: true).environment(\.locale, .init(identifier: "en")) }
#Preview("💻 EN 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 1, isPad: true).environment(\.locale, .init(identifier: "en")) }
#Preview("💻 EN 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 2, isPad: true).environment(\.locale, .init(identifier: "en")) }
#Preview("💻 EN 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 3, isPad: true).environment(\.locale, .init(identifier: "en")) }
#Preview("💻 EN 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 4, isPad: true).environment(\.locale, .init(identifier: "en")) }
#Preview("💻 EN 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .en, index: 5, isPad: true).environment(\.locale, .init(identifier: "en")) }

#Preview("💻 DE 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 0, isPad: true).environment(\.locale, .init(identifier: "de")) }
#Preview("💻 DE 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 1, isPad: true).environment(\.locale, .init(identifier: "de")) }
#Preview("💻 DE 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 2, isPad: true).environment(\.locale, .init(identifier: "de")) }
#Preview("💻 DE 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 3, isPad: true).environment(\.locale, .init(identifier: "de")) }
#Preview("💻 DE 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 4, isPad: true).environment(\.locale, .init(identifier: "de")) }
#Preview("💻 DE 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .de, index: 5, isPad: true).environment(\.locale, .init(identifier: "de")) }

#Preview("💻 ES 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 0, isPad: true).environment(\.locale, .init(identifier: "es")) }
#Preview("💻 ES 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 1, isPad: true).environment(\.locale, .init(identifier: "es")) }
#Preview("💻 ES 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 2, isPad: true).environment(\.locale, .init(identifier: "es")) }
#Preview("💻 ES 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 3, isPad: true).environment(\.locale, .init(identifier: "es")) }
#Preview("💻 ES 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 4, isPad: true).environment(\.locale, .init(identifier: "es")) }
#Preview("💻 ES 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .es, index: 5, isPad: true).environment(\.locale, .init(identifier: "es")) }

#Preview("💻 FR 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 0, isPad: true).environment(\.locale, .init(identifier: "fr")) }
#Preview("💻 FR 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 1, isPad: true).environment(\.locale, .init(identifier: "fr")) }
#Preview("💻 FR 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 2, isPad: true).environment(\.locale, .init(identifier: "fr")) }
#Preview("💻 FR 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 3, isPad: true).environment(\.locale, .init(identifier: "fr")) }
#Preview("💻 FR 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 4, isPad: true).environment(\.locale, .init(identifier: "fr")) }
#Preview("💻 FR 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .fr, index: 5, isPad: true).environment(\.locale, .init(identifier: "fr")) }

#Preview("💻 IT 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 0, isPad: true).environment(\.locale, .init(identifier: "it")) }
#Preview("💻 IT 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 1, isPad: true).environment(\.locale, .init(identifier: "it")) }
#Preview("💻 IT 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 2, isPad: true).environment(\.locale, .init(identifier: "it")) }
#Preview("💻 IT 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 3, isPad: true).environment(\.locale, .init(identifier: "it")) }
#Preview("💻 IT 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 4, isPad: true).environment(\.locale, .init(identifier: "it")) }
#Preview("💻 IT 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .it, index: 5, isPad: true).environment(\.locale, .init(identifier: "it")) }

#Preview("💻 KO 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 0, isPad: true).environment(\.locale, .init(identifier: "ko")) }
#Preview("💻 KO 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 1, isPad: true).environment(\.locale, .init(identifier: "ko")) }
#Preview("💻 KO 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 2, isPad: true).environment(\.locale, .init(identifier: "ko")) }
#Preview("💻 KO 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 3, isPad: true).environment(\.locale, .init(identifier: "ko")) }
#Preview("💻 KO 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 4, isPad: true).environment(\.locale, .init(identifier: "ko")) }
#Preview("💻 KO 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .ko, index: 5, isPad: true).environment(\.locale, .init(identifier: "ko")) }

#Preview("💻 TH 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 0, isPad: true).environment(\.locale, .init(identifier: "th")) }
#Preview("💻 TH 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 1, isPad: true).environment(\.locale, .init(identifier: "th")) }
#Preview("💻 TH 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 2, isPad: true).environment(\.locale, .init(identifier: "th")) }
#Preview("💻 TH 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 3, isPad: true).environment(\.locale, .init(identifier: "th")) }
#Preview("💻 TH 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 4, isPad: true).environment(\.locale, .init(identifier: "th")) }
#Preview("💻 TH 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .th, index: 5, isPad: true).environment(\.locale, .init(identifier: "th")) }

#Preview("💻 TR 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 0, isPad: true).environment(\.locale, .init(identifier: "tr")) }
#Preview("💻 TR 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 1, isPad: true).environment(\.locale, .init(identifier: "tr")) }
#Preview("💻 TR 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 2, isPad: true).environment(\.locale, .init(identifier: "tr")) }
#Preview("💻 TR 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 3, isPad: true).environment(\.locale, .init(identifier: "tr")) }
#Preview("💻 TR 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 4, isPad: true).environment(\.locale, .init(identifier: "tr")) }
#Preview("💻 TR 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .tr, index: 5, isPad: true).environment(\.locale, .init(identifier: "tr")) }

#Preview("💻 VI 01 Home iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 0, isPad: true).environment(\.locale, .init(identifier: "vi")) }
#Preview("💻 VI 02 PDF iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 1, isPad: true).environment(\.locale, .init(identifier: "vi")) }
#Preview("💻 VI 03 Highlight iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 2, isPad: true).environment(\.locale, .init(identifier: "vi")) }
#Preview("💻 VI 04 Languages iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 3, isPad: true).environment(\.locale, .init(identifier: "vi")) }
#Preview("💻 VI 05 Voice iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 4, isPad: true).environment(\.locale, .init(identifier: "vi")) }
#Preview("💻 VI 06 MyFiles iPad", traits: .fixedLayout(width: 512, height: 683)) { Shot(s: .vi, index: 5, isPad: true).environment(\.locale, .init(identifier: "vi")) }

#endif
