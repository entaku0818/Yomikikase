package com.entaku.VoiceYourText.review

import com.entaku.VoiceYourText.analytics.RecordingAnalyticsClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit

/** iOS ReviewRequestTests の起動時判定と同じ条件 */
class ReviewPolicyTest {
    private val now = TimeUnit.DAYS.toMillis(1000)
    private fun daysAgo(days: Long) = now - TimeUnit.DAYS.toMillis(days)

    @Test fun 初回起動では出さない() =
        assertFalse(ReviewPolicy.shouldPrompt(1, false, null, now))

    @Test fun 二回目以降の起動で未確認なら出す() {
        assertTrue(ReviewPolicy.shouldPrompt(2, false, null, now))
        assertTrue(ReviewPolicy.shouldPrompt(50, false, null, now))
    }

    @Test fun 起動時広告を出した起動では出さない() =
        assertFalse(ReviewPolicy.shouldPrompt(5, true, null, now))

    @Test fun 前回から90日未満なら出さない() {
        assertFalse(ReviewPolicy.shouldPrompt(3, false, now, now))
        assertFalse(ReviewPolicy.shouldPrompt(3, false, daysAgo(89), now))
    }

    @Test fun 前回から90日以上なら出す() {
        assertTrue(ReviewPolicy.shouldPrompt(3, false, daysAgo(90), now))
        assertTrue(ReviewPolicy.shouldPrompt(3, false, daysAgo(400), now))
    }

    @Test fun いいえと答えたら評価ダイアログは呼ばない() {
        val analytics = RecordingAnalyticsClient()
        ReviewRequester(analytics).onAnswer(satisfied = false, activity = null)
        assertEquals(listOf("review_prompt_answer" to mapOf("answer" to "no")), analytics.events)
    }
}
