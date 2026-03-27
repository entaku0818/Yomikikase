package com.entaku.VoiceYourText

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

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
                MainApp(initialSharedText = sharedText)
            }
        }
    }
}
