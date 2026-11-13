package com.entaku.VoiceYourText.kokoro

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.res.AssetManager
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.LongBuffer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject

/** Serializes inference so rapid previews cannot race or multiply native memory usage. */
class KokoroSynthesizer(private val models: KokoroModelStore, private val assets: AssetManager) {
    private val mutex = Mutex()
    private var session: OrtSession? = null
    private var closed = false
    private var g2p: JapanesePhonemes? = null
    private var vocab: JSONObject? = null
    private val voices = mutableMapOf<KokoroVoice, ByteArray>()

    suspend fun synthesize(text: String, voice: KokoroVoice, speed: Float): ByteArray = withContext(Dispatchers.Default) {
        mutex.withLock {
            currentCoroutineContext().ensureActive()
            check(!closed)
            require(text.isNotBlank() && text.length <= 2000)
            require(speed.isFinite() && speed in 0.5f..2f)
            val env = OrtEnvironment.getEnvironment()
            val engine = session ?: run {
                val file = models.verifiedModel()
                currentCoroutineContext().ensureActive()
                OrtSession.SessionOptions().use { options ->
                    options.setIntraOpNumThreads(2)
                    env.createSession(file.absolutePath, options)
                }.also { session = it }
            }
            currentCoroutineContext().ensureActive()
            val dictionary = vocab ?: assets.open("kokoro/tokenizer.json").bufferedReader().use { reader ->
                JSONObject(reader.readText()).getJSONObject("model").getJSONObject("vocab")
            }.also { vocab = it }
            val embedding = voices.getOrPut(voice) { assets.open("kokoro/${voice.voiceId}.bin").use { it.readBytes() } }
            check(embedding.size == 510 * 256 * 4)
            val phonemes = (g2p ?: JapanesePhonemes().also { g2p = it }).convert(text)
            require(phonemes.any { it.isLetter() })
            val pcm = ByteArrayOutputStream()
            KokoroPhonemeChunker.synthesize(phonemes) { chunk ->
                val ids = longArrayOf(0) + chunk.map { c ->
                    require(dictionary.has(c.toString())) { "Unsupported phoneme: $c" }
                    dictionary.getLong(c.toString())
                }.toLongArray() + longArrayOf(0)
                // ONNX model card: style index is the unpadded token count.
                val style = ByteBuffer.wrap(embedding, chunk.length * 256 * 4, 1024)
                    .order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
                OnnxTensor.createTensor(env, LongBuffer.wrap(ids), longArrayOf(1, ids.size.toLong())).use { input ->
                    OnnxTensor.createTensor(env, style, longArrayOf(1, 256)).use { styleTensor ->
                        OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(speed)), longArrayOf(1)).use { speedTensor ->
                            engine.run(mapOf("input_ids" to input, "style" to styleTensor, "speed" to speedTensor)).use { result ->
                                currentCoroutineContext().ensureActive()
                                val audio = (result[0] as OnnxTensor).floatBuffer
                                val bytes = ByteBuffer.allocate(audio.remaining() * 2).order(ByteOrder.LITTLE_ENDIAN)
                                while (audio.hasRemaining()) {
                                    val sample = audio.get()
                                    require(sample.isFinite())
                                    bytes.putShort((sample.coerceIn(-1f, 1f) * 32767).toInt().toShort())
                                }
                                pcm.write(bytes.array())
                            }
                        }
                    }
                }
            }
            currentCoroutineContext().ensureActive()
            val samples = pcm.toByteArray()
            check(samples.isNotEmpty())
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray()).putInt(36 + samples.size).put("WAVEfmt ".toByteArray())
                .putInt(16).putShort(1).putShort(1).putInt(24000).putInt(48000)
                .putShort(2).putShort(16).put("data".toByteArray()).putInt(samples.size)
            header.array() + samples
        }
    }

    suspend fun close() = withContext(Dispatchers.Default) {
        mutex.withLock {
            closed = true
            session?.close()
            session = null
            voices.clear()
            g2p = null
        }
    }
}
