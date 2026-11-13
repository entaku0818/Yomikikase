package com.entaku.VoiceYourText.kokoro

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.assertIsDisplayed
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.platform.app.InstrumentationRegistry
import com.entaku.VoiceYourText.tts.SpeechLanguage
import com.entaku.VoiceYourText.tts.TtsState
import com.entaku.VoiceYourText.tts.TtsViewModel
import com.entaku.VoiceYourText.ui.theme.VoiceYourTextTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class KokoroProductionUiTest {
    @get:Rule val compose = createComposeRule()

    @Test fun selectAllVoicesAndReadCustomTextThroughProductionViewModel() {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("kokoroModelTest") == "true")
        val app = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application
        val owner = ViewModelStore()
        lateinit var vm: TtsViewModel
        compose.runOnUiThread {
            vm = ViewModelProvider(owner, ViewModelProvider.AndroidViewModelFactory(app))[TtsViewModel::class.java]
            vm.setLanguage(SpeechLanguage.JAPANESE)
        }
        try {
            compose.setContent { VoiceYourTextTheme { KokoroVoiceSection(vm) } }
            KokoroVoice.entries.forEach { voice ->
                compose.onNodeWithText(voice.displayName).assertIsDisplayed().performClick()
                compose.runOnIdle {
                    assertTrue(vm.kokoroEnabled.value)
                    assertEquals(voice, vm.kokoroVoice.value)
                    assertFalse(vm.voicevoxEnabled.value)
                }
            }
            compose.runOnIdle {
                vm.speak("朝の公園で、鳥の声を聞きました。", saveToMyFiles = false)
            }
            compose.waitUntil(60_000) { vm.highlight.value != null || vm.kokoroError.value }
            compose.runOnIdle {
                assertFalse(vm.kokoroError.value)
                assertEquals(TtsState.SPEAKING, vm.state.value)
                vm.pause()
                assertEquals(TtsState.PAUSED, vm.state.value)
                vm.resume()
            }
            compose.waitUntil(60_000) { vm.state.value == TtsState.IDLE || vm.kokoroError.value }
            compose.runOnIdle {
                assertFalse(vm.kokoroError.value)
                vm.speak("こんにちは。".repeat(100), saveToMyFiles = false)
                vm.stop()
                assertEquals(TtsState.IDLE, vm.state.value)
                assertFalse(vm.kokoroGenerating.value)
                vm.speak("。。。", saveToMyFiles = false)
                assertEquals(TtsState.IDLE, vm.state.value)
                vm.speak("こんにちは。".repeat(100), saveToMyFiles = false)
                vm.setVoice(null)
                assertFalse(vm.kokoroEnabled.value)
                assertEquals(TtsState.IDLE, vm.state.value)
            }
            // Regression: immediate Stop used to crash later with the foreground-service timeout.
            android.os.SystemClock.sleep(6_000)
            compose.runOnIdle { assertEquals(TtsState.IDLE, vm.state.value) }
        } finally { compose.runOnUiThread { owner.clear() } }
    }
}
