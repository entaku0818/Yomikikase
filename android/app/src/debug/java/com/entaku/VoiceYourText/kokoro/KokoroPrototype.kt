package com.entaku.VoiceYourText.kokoro

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.LongBuffer

/** Debug-only CPU proof of concept. Assets are provisioned by scripts/prepare_kokoro.py. */
class KokoroPrototype(private val directory: File) : AutoCloseable {
    private val env = OrtEnvironment.getEnvironment()
    private val voice = File(directory, "voice.bin").readBytes()
    private val vocab = JSONObject(File(directory, "tokenizer.json").readText()).getJSONObject("model").getJSONObject("vocab")
    private val g2p = JapanesePhonemes()

    private val session = OrtSession.SessionOptions().use { options ->
        options.setIntraOpNumThreads(2)
        env.createSession(File(directory, "model.onnx").absolutePath, options)
    }

    data class Result(val file: File, val phonemes: String, val seconds: Double, val synthesisMillis: Long, val chunks: Int) {
        val realTimeFactor: Double get() = synthesisMillis / 1000.0 / seconds
    }

    suspend fun synthesize(text: String, speed: Float = 1f): Result {
        currentCoroutineContext().ensureActive()
        require(text.isNotBlank() && text.length <= 2000) { "試作では1〜2000文字を入力してください" }
        require(speed.isFinite() && speed in 0.5f..2f)
        val start = System.nanoTime()
        val phonemes = g2p.convert(text)
        require(phonemes.any { it.isLetter() }) { "読み上げる文字がありません" }
        var chunkCount = 0
        val target = File(directory, "sample.wav")
        val partial = File.createTempFile("sample-", ".partial", directory)
        var sampleCount = 0
        try {
            RandomAccessFile(partial, "rw").use { wav ->
                wav.setLength(0)
                wav.write(ByteArray(44))
                chunkCount = KokoroPhonemeChunker.synthesize(phonemes) { chunk ->
                    currentCoroutineContext().ensureActive()
                    val ids = longArrayOf(0) + chunk.map { c ->
                        require(vocab.has(c.toString())) { "未対応の音素: $c" }
                        vocab.getLong(c.toString())
                    }.toLongArray() + longArrayOf(0)
                    val styleOffset = chunk.length * 256 * 4
                    require(styleOffset + 1024 <= voice.size) { "音声データが不正です" }
                    val style = ByteBuffer.wrap(voice, styleOffset, 1024).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
                    OnnxTensor.createTensor(env, LongBuffer.wrap(ids), longArrayOf(1, ids.size.toLong())).use { input ->
                        OnnxTensor.createTensor(env, style, longArrayOf(1, 256)).use { styleTensor ->
                            OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(speed)), longArrayOf(1)).use { speedTensor ->
                                session.run(mapOf("input_ids" to input, "style" to styleTensor, "speed" to speedTensor)).use { result ->
                                    currentCoroutineContext().ensureActive()
                                    val audio = (result[0] as OnnxTensor).floatBuffer
                                    val pcm = ByteBuffer.allocate(audio.remaining() * 2).order(ByteOrder.LITTLE_ENDIAN)
                                    while (audio.hasRemaining()) {
                                        val sample = audio.get()
                                        require(sample.isFinite()) { "音声に不正な値が含まれています" }
                                        pcm.putShort((sample.coerceIn(-1f, 1f) * 32767).toInt().toShort())
                                        sampleCount++
                                    }
                                    wav.write(pcm.array())
                                }
                            }
                        }
                    }
                }
                currentCoroutineContext().ensureActive()
                require(sampleCount > 0)
                wav.seek(0)
                val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                header.put("RIFF".toByteArray()).putInt(36 + sampleCount * 2).put("WAVEfmt ".toByteArray())
                    .putInt(16).putShort(1).putShort(1).putInt(24000).putInt(48000)
                    .putShort(2).putShort(16).put("data".toByteArray()).putInt(sampleCount * 2)
                wav.write(header.array())
            }
            currentCoroutineContext().ensureActive()
            check(partial.renameTo(target)) { "音声ファイルを保存できません" }
            return Result(target, phonemes, sampleCount / 24000.0, (System.nanoTime() - start) / 1_000_000, chunkCount)
        } finally {
            partial.delete()
        }
    }

    companion object {
        internal fun chunks(phonemes: String): List<String> = KokoroPhonemeChunker.chunks(phonemes)
    }

    override fun close() { session.close() }
}
