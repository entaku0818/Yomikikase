package com.entaku.VoiceYourText.review

import android.app.Activity
import android.content.SharedPreferences
import androidx.core.content.edit
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.google.android.play.core.review.ReviewManagerFactory
import java.util.concurrent.TimeUnit

/**
 * レビュー依頼の発火条件（iOS `Data/ReviewRequestPrompt.swift` と同じ）。
 * 2回目以降の起動・前回から90日以上・起動時広告を出した起動ではない、を満たすと
 * 満足度を1問聞き、はい → Google Play の評価ダイアログ / いいえ → フィードバック画面。
 * 実際に評価ダイアログを出すかは Google Play が決める（回数制限は Play 側にある）。
 */
object ReviewPolicy {
    const val MINIMUM_LAUNCH_COUNT = 2
    const val MINIMUM_DAYS = 90L
    const val DELAY_MILLIS = 2_000L

    fun shouldPrompt(
        launchCount: Int,
        didShowAppOpenAd: Boolean,
        lastPromptAtMillis: Long?,
        nowMillis: Long,
    ): Boolean {
        if (launchCount < MINIMUM_LAUNCH_COUNT || didShowAppOpenAd) return false
        if (lastPromptAtMillis == null) return true
        return nowMillis - lastPromptAtMillis >= TimeUnit.DAYS.toMillis(MINIMUM_DAYS)
    }
}

/** 起動回数と前回の確認日時を保存する */
class ReviewPromptStore(private val prefs: SharedPreferences) {

    /** cold start ごとに1回だけ呼ぶ */
    fun incrementLaunchCount(): Int {
        val count = prefs.getInt(KEY_LAUNCH_COUNT, 0) + 1
        prefs.edit { putInt(KEY_LAUNCH_COUNT, count) }
        return count
    }

    val lastPromptAtMillis: Long?
        get() = prefs.getLong(KEY_LAST_PROMPT_AT, -1L).takeIf { it >= 0 }

    fun markPrompted(nowMillis: Long) {
        prefs.edit { putLong(KEY_LAST_PROMPT_AT, nowMillis) }
    }

    companion object {
        const val PREFS_NAME = "review_request"
        private const val KEY_LAUNCH_COUNT = "launch_count"
        private const val KEY_LAST_PROMPT_AT = "last_prompt_at"
    }
}

/** 満足度確認への回答を処理する。イベント名は iOS と同じ */
class ReviewRequester(private val analytics: AnalyticsClient) {

    fun onPromptShown(launchCount: Int) {
        analytics.logEvent("review_prompt_shown", mapOf("trigger" to "launch", "launch_count" to launchCount))
    }

    /** はい → Play の評価ダイアログを呼ぶ。いいえの場合のフィードバック画面は呼び出し側で出す */
    fun onAnswer(satisfied: Boolean, activity: Activity?) {
        analytics.logEvent("review_prompt_answer", mapOf("answer" to if (satisfied) "yes" else "no"))
        if (!satisfied || activity == null) return
        analytics.logEvent("review_request_system", mapOf("trigger" to "launch"))
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { task ->
            if (task.isSuccessful) manager.launchReviewFlow(activity, task.result)
        }
    }
}
