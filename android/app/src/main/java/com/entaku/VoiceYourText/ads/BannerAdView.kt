package com.entaku.VoiceYourText.ads

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.entaku.VoiceYourText.BuildConfig
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView

/**
 * バナー広告。表示・クリック・表示ごとの推定収益を iOS と同じイベント名で GA4 に送る
 * （ad_banner_impression / ad_banner_click / ad_banner_paid、placement 付き）。
 */
@Composable
fun BannerAdView(placement: String, modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier.fillMaxWidth(),
        factory = { context ->
            val analytics = AnalyticsClient.get(context)
            AdView(context).apply {
                setAdSize(AdSize.BANNER)
                adUnitId = BuildConfig.BANNER_AD_UNIT_ID
                adListener = object : AdListener() {
                    override fun onAdImpression() {
                        analytics.logEvent("ad_banner_impression", mapOf("placement" to placement))
                    }

                    override fun onAdClicked() {
                        analytics.logEvent("ad_banner_click", mapOf("placement" to placement))
                    }
                }
                // AdMob の「インプレッション単位の広告収益」が有効なときだけ届く
                setOnPaidEventListener { adValue ->
                    analytics.logEvent(
                        "ad_banner_paid",
                        mapOf(
                            "placement" to placement,
                            "value" to adValue.valueMicros / 1_000_000.0,
                            "currency" to adValue.currencyCode,
                            "precision" to adValue.precisionType,
                        )
                    )
                }
                loadAd(AdRequest.Builder().build())
            }
        }
    )
}
