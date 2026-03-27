package com.entaku.VoiceYourText

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            VoiceYourTextTheme {
                MainApp()
            }
        }
    }
}
