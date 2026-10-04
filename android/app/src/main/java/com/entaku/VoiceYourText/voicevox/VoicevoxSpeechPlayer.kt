package com.entaku.VoiceYourText.voicevox

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import com.entaku.VoiceYourText.tts.TextRange
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** 音声ファイルを鳴らす先。テストでは偽物に差し替える */
interface VoicevoxAudioOutput {
    /** file を最後まで再生したら返る。コルーチンがキャンセルされたら再生を止める */
    suspend fun play(file: File)
    fun stop()
}

/**
 * キャラ音声（VOICEVOX）で文章を読み上げる（iOS VoicevoxSpeechPlayer と同じ流れ）。
 *
 * 文ごとにサーバーで音声を作り、1文目ができた時点で再生を始める。再生中に次の文を先に作っておくので、
 * 生成が再生より速ければ文の間で待たない。作った音声は端末に保存し、同じ文・声・速度なら保存済みを使う。
 */
class VoicevoxSpeechPlayer(
    private val scope: CoroutineScope,
    private val synthesize: suspend (text: String, speakerId: Int, speedScale: Double) -> ByteArray,
    private val cache: VoicevoxAudioCache,
    private val output: VoicevoxAudioOutput,
    private val tempDir: File,
    private val log: (String, Throwable) -> Unit = { message, e -> Log.w("Voicevox", message, e) },
) {
    sealed class Event {
        /** この文の再生を始めた（元の文章の中の位置）。ハイライトに使う */
        data class Sentence(val range: TextRange) : Event()
        /** 最後まで読んだ */
        data object Finished : Event()
        /** 今月の上限に達した。resumeAt（元の文章の位置）から先は読めていない */
        data class QuotaExceeded(val usage: VoicevoxUsage, val resumeAt: Int) : Event()
        /** 通信エラーなどで止まった。resumeAt から先を端末の音声で読み直せる */
        data class Failed(val resumeAt: Int) : Event()
    }

    private var job: Job? = null

    val isPlaying: Boolean get() = job?.isActive == true

    /**
     * text を読む。offset は text が元の文章のどこから始まるか（途中から読み直すとき）で、
     * イベントの位置はすべて元の文章の上の位置になる。onEvent は scope のスレッドで呼ばれる。
     */
    fun play(text: String, speakerId: Int, speedScale: Double, offset: Int = 0, onEvent: (Event) -> Unit) {
        stop()
        val chunks = VoicevoxTextChunker.chunks(text)
        job = scope.launch { run(chunks, speakerId, speedScale, offset, onEvent) }
    }

    fun stop() {
        job?.cancel()
        job = null
        output.stop()
    }

    private suspend fun run(
        chunks: List<VoicevoxTextChunker.Chunk>,
        speakerId: Int,
        speedScale: Double,
        offset: Int,
        onEvent: (Event) -> Unit,
    ) = supervisorScope {
        if (chunks.isEmpty()) {
            onEvent(Event.Finished)
            return@supervisorScope
        }
        fun prefetch(index: Int): Deferred<File> = async(Dispatchers.IO) { audioFile(chunks[index], speakerId, speedScale) }

        var pending: Deferred<File>? = prefetch(0)
        for (index in chunks.indices) {
            val resumeAt = chunks[index].range.start + offset
            val file = try {
                pending!!.await()
            } catch (e: CancellationException) {
                throw e
            } catch (e: VoicevoxException.QuotaExceeded) {
                onEvent(Event.QuotaExceeded(e.usage, resumeAt))
                return@supervisorScope
            } catch (e: Exception) {
                log("synthesis failed at chunk $index", e)
                onEvent(Event.Failed(resumeAt))
                return@supervisorScope
            }

            // 再生している間に次の文を作っておく
            pending = if (index + 1 < chunks.size) prefetch(index + 1) else null

            val range = chunks[index].range
            onEvent(Event.Sentence(TextRange(range.start + offset, range.length)))
            try {
                output.play(file)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // 壊れた音声などで再生できなかったときは、その文から端末の音声で読み直す
                log("playback failed at chunk $index", e)
                pending?.cancel()
                onEvent(Event.Failed(resumeAt))
                return@supervisorScope
            }
        }
        onEvent(Event.Finished)
    }

    private suspend fun audioFile(chunk: VoicevoxTextChunker.Chunk, speakerId: Int, speedScale: Double): File {
        cache.load(chunk.text, speakerId, speedScale)?.let { return it }
        val data = synthesize(chunk.text, speakerId, speedScale)
        return try {
            cache.store(data, chunk.text, speakerId, speedScale)
        } catch (e: Exception) {
            // 保存できなくても再生はできる。次回また作るだけ
            log("cache write failed", e)
            withContext(Dispatchers.IO) {
                File.createTempFile("voicevox", ".m4a", tempDir).apply {
                    deleteOnExit()
                    writeBytes(data)
                }
            }
        }
    }
}

/** MediaPlayer で鳴らす */
class MediaPlayerOutput : VoicevoxAudioOutput {
    private var player: MediaPlayer? = null

    override suspend fun play(file: File) = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { continuation ->
            val mediaPlayer = MediaPlayer()
            player?.release()
            player = mediaPlayer
            continuation.invokeOnCancellation {
                // メインスレッド以外から呼ばれることがあるので、解放はメインに回す
                android.os.Handler(android.os.Looper.getMainLooper()).post { release(mediaPlayer) }
            }
            try {
                mediaPlayer.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                mediaPlayer.setDataSource(file.path)
                mediaPlayer.setOnCompletionListener {
                    release(mediaPlayer)
                    if (continuation.isActive) continuation.resume(Unit)
                }
                mediaPlayer.setOnErrorListener { _, what, extra ->
                    release(mediaPlayer)
                    if (continuation.isActive) continuation.resumeWithException(java.io.IOException("MediaPlayer error $what/$extra"))
                    true
                }
                mediaPlayer.prepare()
                mediaPlayer.start()
            } catch (e: Exception) {
                release(mediaPlayer)
                if (continuation.isActive) continuation.resumeWithException(e)
            }
        }
    }

    override fun stop() {
        player?.let(::release)
    }

    private fun release(mediaPlayer: MediaPlayer) {
        if (player === mediaPlayer) player = null
        runCatching { mediaPlayer.stop() }
        mediaPlayer.release()
    }
}
