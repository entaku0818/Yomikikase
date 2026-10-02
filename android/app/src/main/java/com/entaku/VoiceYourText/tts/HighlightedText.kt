package com.entaku.VoiceYourText.tts

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * 読み上げ中の箇所を色付けして表示し、その行が見えるよう自動でスクロールする
 * （iOS `Shared/HighlightableTextView.swift` 相当）。
 */
@Composable
fun HighlightedText(
    text: String,
    range: TextRange?,
    modifier: Modifier = Modifier,
) {
    val scrollState = rememberScrollState()
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val primary = MaterialTheme.colorScheme.primary
    val style = SpanStyle(background = primary.copy(alpha = 0.22f), color = primary, fontWeight = FontWeight.Bold)
    val annotated = remember(text, range, style) { highlighted(text, range, style) }

    // 読んでいる行を上から1/3あたりに保つ
    LaunchedEffect(range, layout) {
        val result = layout ?: return@LaunchedEffect
        val start = range?.start?.coerceIn(0, text.length) ?: return@LaunchedEffect
        val line = result.getLineForOffset(start)
        val target = (result.getLineTop(line) - scrollState.viewportSize / 3f).toInt().coerceAtLeast(0)
        scrollState.animateScrollTo(target.coerceAtMost(scrollState.maxValue))
    }

    Box(
        modifier = modifier
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
            .verticalScroll(scrollState)
            .padding(16.dp)
    ) {
        Text(
            text = annotated,
            style = MaterialTheme.typography.bodyLarge,
            onTextLayout = { layout = it }
        )
    }
}

/** range の部分にだけ style を当てた文字列。範囲外は切り詰める */
fun highlighted(text: String, range: TextRange?, style: SpanStyle): AnnotatedString = buildAnnotatedString {
    append(text)
    if (range != null) {
        val start = range.start.coerceIn(0, text.length)
        val end = range.end.coerceIn(start, text.length)
        if (end > start) addStyle(style, start, end)
    }
}
