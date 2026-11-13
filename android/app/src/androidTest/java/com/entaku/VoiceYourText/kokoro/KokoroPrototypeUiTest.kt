package com.entaku.VoiceYourText.kokoro

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextReplacement
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test

class KokoroPrototypeUiTest {
    @get:Rule val compose = createAndroidComposeRule<KokoroPrototypeActivity>()

    @Test fun stopButtonCancelsSynthesisAndAllowsAnotherRequest() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("kokoroModelTest") == "true")
        compose.onNodeWithText("日本語（最大2000文字）")
            .performTextReplacement("こんにちは。今日は東京で本を読みます。".repeat(12))
        compose.onNodeWithText("音声を生成").performClick()
        compose.onNodeWithText("合成を停止").performClick()
        compose.waitUntil(timeoutMillis = 30_000) {
            compose.onAllNodesWithText("合成を停止しました").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("音声を生成").assertIsEnabled()
    }
}
