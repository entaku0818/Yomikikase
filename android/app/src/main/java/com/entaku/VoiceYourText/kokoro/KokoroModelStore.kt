package com.entaku.VoiceYourText.kokoro

import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

data class KokoroDownloadState(
    val ready: Boolean = false,
    val downloading: Boolean = false,
    val progress: Float = 0f,
    val failed: Boolean = false,
)

/** A pinned, verified model; incomplete downloads never become playable. */
class KokoroModelStore(
    private val directory: File,
    private val url: String = MODEL_URL,
    private val expectedBytes: Long = MODEL_BYTES,
    private val expectedHash: String = MODEL_SHA256,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS).readTimeout(15, TimeUnit.SECONDS).build(),
) {
    val modelFile = File(directory, "model.onnx")
    private val mutex = Mutex()
    private val _state = MutableStateFlow(KokoroDownloadState(ready = modelFile.length() == expectedBytes))
    val state = _state.asStateFlow()

    suspend fun verifiedModel(): File = withContext(Dispatchers.IO) {
        if (!valid(modelFile)) {
            _state.value = KokoroDownloadState(failed = true)
            error("Kokoro model is missing or corrupt")
        }
        modelFile
    }

    suspend fun download() = mutex.withLock {
        withContext(Dispatchers.IO) {
            _state.value = KokoroDownloadState(downloading = true)
            directory.mkdirs()
            val partial = File(directory, "model.partial")
            try {
                if (!valid(modelFile)) {
                    client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                        if (!response.isSuccessful) throw IOException("Model HTTP ${response.code}")
                        val body = response.body ?: throw IOException("Missing model body")
                        if (body.contentLength() > 0 && body.contentLength() != expectedBytes) {
                            throw IOException("Unexpected model length")
                        }
                        body.byteStream().use { input ->
                            partial.outputStream().use { output ->
                                val buffer = ByteArray(64 * 1024)
                                var total = 0L
                                while (true) {
                                    currentCoroutineContext().ensureActive()
                                    val count = input.read(buffer)
                                    if (count == -1) break
                                    total += count
                                    if (total > expectedBytes) throw IOException("Model is too large")
                                    output.write(buffer, 0, count)
                                    _state.value = KokoroDownloadState(downloading = true, progress = total.toFloat() / expectedBytes)
                                }
                            }
                        }
                    }
                    currentCoroutineContext().ensureActive()
                    if (!valid(partial)) throw IOException("Model checksum mismatch")
                    currentCoroutineContext().ensureActive()
                    if (!partial.renameTo(modelFile)) throw IOException("Cannot save model")
                }
                currentCoroutineContext().ensureActive()
                _state.value = KokoroDownloadState(ready = true)
            } catch (e: CancellationException) {
                _state.value = KokoroDownloadState(ready = modelFile.length() == expectedBytes)
                throw e
            } catch (e: Exception) {
                _state.value = KokoroDownloadState(failed = true)
                throw e
            } finally {
                partial.delete()
            }
        }
    }

    private suspend fun valid(file: File): Boolean {
        if (!file.isFile || file.length() != expectedBytes) return false
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                currentCoroutineContext().ensureActive()
                val count = input.read(buffer)
                if (count == -1) break
                hash.update(buffer, 0, count)
            }
        }
        return hash.digest().joinToString("") { "%02x".format(it) } == expectedHash
    }

    companion object {
        const val REVISION = "1939ad2a8e416c0acfeecc08a694d14ef25f2231"
        const val MODEL_URL = "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/$REVISION/onnx/model_quantized.onnx"
        const val MODEL_BYTES = 92361116L
        const val MODEL_SHA256 = "fbae9257e1e05ffc727e951ef9b9c98418e6d79f1c9b6b13bd59f5c9028a1478"
    }
}
