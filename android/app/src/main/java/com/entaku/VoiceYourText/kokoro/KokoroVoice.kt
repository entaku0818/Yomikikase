package com.entaku.VoiceYourText.kokoro

/** Stable IDs are used in saved settings and the local audio cache. */
enum class KokoroVoice(val voiceId: String, val displayName: String, val cacheId: Int) {
    RIN("jf_alpha", "凛", 0),
    KITSUNE("jf_gongitsune", "狐", 1),
    YUKI("jf_tebukuro", "雪", 2),
    ME("jf_nezumi", "芽", 3),
    KUMO("jm_kumo", "雲", 4);

    companion object {
        fun fromId(id: String?): KokoroVoice? = entries.firstOrNull { it.voiceId == id }
        const val PREVIEW_TEXT = "こんにちは。やわらかな風が吹いています。好きな本を、一緒に読んでみませんか。"
    }
}
