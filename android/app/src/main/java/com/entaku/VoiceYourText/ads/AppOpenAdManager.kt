package com.entaku.VoiceYourText.ads

import android.app.Activity
import android.content.Context
import androidx.core.content.edit
import com.entaku.VoiceYourText.BuildConfig
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.appopen.AppOpenAd
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * 起動時の全画面広告（App Open）。iOS `AppOpenAdManager` と同じルール:
 * - cold start のときだけ（バックグラウンド再生からの復帰では出さない）
 * - 3回に1回（専用のカウンタで数える）
 * - プレミアム会員・オンボーディング中は出さない
 * - ロードは最大4秒待つ。間に合わなければ出さない
 */
object AppOpenAdGate {
    const val SHOW_EVERY_N_LAUNCHES = 3

    fun shouldShow(launchCount: Int, isPremium: Boolean, hasCompletedOnboarding: Boolean): Boolean =
        launchCount > 0 && !isPremium && hasCompletedOnboarding && launchCount % SHOW_EVERY_N_LAUNCHES == 0
}

object AppOpenAdManager {
    private const val PREFS = "app_open_ad"
    private const val KEY_LAUNCH_COUNT = "launch_count"
    private const val LOAD_TIMEOUT_MILLIS = 4_000L

    /**
     * 起動時に1回だけ呼ぶ。表示回なら広告を読み込んで出し、閉じられるまで待つ。
     * @return 広告を表示したか（レビュー依頼を同じ起動で出さないために使う）
     */
    suspend fun showOnColdStartIfEligible(activity: Activity, isPremium: Boolean, hasCompletedOnboarding: Boolean): Boolean {
        val analytics = AnalyticsClient.get(activity)
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val launchCount = prefs.getInt(KEY_LAUNCH_COUNT, 0) + 1
        prefs.edit { putInt(KEY_LAUNCH_COUNT, launchCount) }

        if (!AppOpenAdGate.shouldShow(launchCount, isPremium, hasCompletedOnboarding)) {
            val reason = when {
                isPremium -> "premium"
                !hasCompletedOnboarding -> "onboarding"
                else -> "launch_gate"
            }
            analytics.logEvent("app_open_ad_skipped", mapOf("reason" to reason, "launch_count" to launchCount))
            return false
        }

        val ad = withTimeoutOrNull(LOAD_TIMEOUT_MILLIS) { load(activity) }
        if (ad == null) {
            analytics.logEvent("app_open_ad_skipped", mapOf("reason" to "load_timeout", "launch_count" to launchCount))
            return false
        }
        ad.setOnPaidEventListener { value ->
            analytics.logEvent(
                "ad_app_open_paid",
                mapOf("value" to value.valueMicros / 1_000_000.0, "currency" to value.currencyCode, "precision" to value.precisionType)
            )
        }
        analytics.logEvent("app_open_ad_shown", mapOf("launch_count" to launchCount))
        show(activity, ad)
        return true
    }

    private suspend fun load(context: Context): AppOpenAd? = suspendCancellableCoroutine { cont ->
        AppOpenAd.load(
            context,
            BuildConfig.APP_OPEN_AD_UNIT_ID,
            AdRequest.Builder().build(),
            object : AppOpenAd.AppOpenAdLoadCallback() {
                override fun onAdLoaded(ad: AppOpenAd) { if (cont.isActive) cont.resume(ad) }
                override fun onAdFailedToLoad(error: LoadAdError) { if (cont.isActive) cont.resume(null) }
            }
        )
    }

    /** 広告を出し、閉じられる（または出せなかった）まで待つ */
    private suspend fun show(activity: Activity, ad: AppOpenAd) = suspendCancellableCoroutine { cont ->
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() { if (cont.isActive) cont.resume(Unit) }
            override fun onAdFailedToShowFullScreenContent(error: AdError) { if (cont.isActive) cont.resume(Unit) }
        }
        ad.show(activity)
    }
}
