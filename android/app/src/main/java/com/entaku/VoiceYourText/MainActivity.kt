package com.entaku.VoiceYourText

import com.entaku.VoiceYourText.billing.PremiumManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme
import com.google.android.gms.ads.MobileAds

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        MobileAds.initialize(this)
        PremiumManager.configure(this)

        // Extract shared text if launched via ACTION_SEND
        val sharedText = if (intent?.action == Intent.ACTION_SEND &&
            intent.type == "text/plain"
        ) {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

        setContent {
            VoiceYourTextTheme {
                // 回転などの再生成では起動回数を数えない（レビュー依頼の判定に使う）
                MainApp(initialSharedText = sharedText, isColdStart = savedInstanceState == null)
            }
        }
    }
}
