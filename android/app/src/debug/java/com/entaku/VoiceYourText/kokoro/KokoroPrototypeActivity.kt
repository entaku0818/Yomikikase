package com.entaku.VoiceYourText.kokoro

import android.media.MediaPlayer
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** Separate debug entry point; no model or experimental dependency enters release builds. */
class KokoroPrototypeActivity : ComponentActivity() {
    private var player: MediaPlayer? = null
    private var synthesisJob: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var text by remember { mutableStateOf("こんにちは。今日は東京の図書館で、日本語の本を読みます。") }
            var status by remember { mutableStateOf("モデルを配置して「音声を生成」を押してください。") }
            var busy by remember { mutableStateOf(false) }
            var ready by remember { mutableStateOf(false) }
            MaterialTheme {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Kokoro 日本語試作", style = MaterialTheme.typography.headlineSmall)
                    Text("端末内合成・jf_alpha / Debug専用。数字は一桁ずつ読みます。未対応文字はエラーで表示します。")
                    OutlinedTextField(text, onValueChange = { text = it }, enabled = !busy, label = { Text("日本語（最大2000文字）") })
                    Button(enabled = !busy && text.isNotBlank() && text.length <= 2000, onClick = {
                        player?.release(); player = null
                        busy = true; ready = false; status = "合成中…"
                        synthesisJob = lifecycleScope.launch {
                            try {
                                val result = withContext(Dispatchers.Default) {
                                    currentCoroutineContext().ensureActive()
                                    KokoroPrototype(File(filesDir, "kokoro")).use { it.synthesize(text) }
                                }
                                status = "合成 ${result.synthesisMillis} ms / 音声 %.1f秒 / RTF %.2f / %dチャンク\n%s".format(
                                    result.seconds, result.realTimeFactor, result.chunks, result.phonemes)
                                ready = true
                            } catch (e: CancellationException) {
                                status = "合成を停止しました"
                                throw e
                            } catch (e: Exception) { status = "合成できません: ${e.message}"
                            } finally { busy = false; synthesisJob = null }
                        }
                    }) { Text("音声を生成") }
                    Button(enabled = ready && !busy, onClick = {
                        player?.release()
                        player = MediaPlayer().apply {
                            setDataSource(File(filesDir, "kokoro/sample.wav").absolutePath)
                            prepare(); start()
                        }
                    }) { Text("試聴") }
                    TextButton(onClick = {
                        synthesisJob?.cancel()
                        player?.release(); player = null
                        if (busy) status = "合成を停止しています…"
                    }) { Text(if (busy) "合成を停止" else "再生停止") }
                    Text(status)
                }
            }
        }
    }

    override fun onStop() {
        synthesisJob?.cancel()
        player?.release(); player = null
        super.onStop()
    }
}
