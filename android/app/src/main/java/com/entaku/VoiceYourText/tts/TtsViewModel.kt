package com.entaku.VoiceYourText.tts

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.analytics.SpeechCompletionTracker
import com.entaku.VoiceYourText.file.SavedFileRepository
import com.entaku.VoiceYourText.file.SourceType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Locale

enum class TtsState {
    IDLE, SPEAKING, PAUSED, ERROR
}

data class SpeechLanguage(
    val locale: Locale,
    val displayName: String
) {
    companion object {
        val JAPANESE = SpeechLanguage(Locale.JAPANESE, "日本語")
        val ENGLISH = SpeechLanguage(Locale.ENGLISH, "English")
        val CHINESE = SpeechLanguage(Locale.CHINESE, "中文")
        val KOREAN = SpeechLanguage(Locale.KOREAN, "한국어")
        val FRENCH = SpeechLanguage(Locale.FRENCH, "Français")
        val GERMAN = SpeechLanguage(Locale.GERMAN, "Deutsch")
        val SPANISH = SpeechLanguage(Locale("es"), "Español")

        val ALL = listOf(JAPANESE, ENGLISH, CHINESE, KOREAN, FRENCH, GERMAN, SPANISH)
    }
}

class TtsViewModel(application: Application) : AndroidViewModel(application) {

    private val _state = MutableStateFlow(TtsState.IDLE)
    val state: StateFlow<TtsState> = _state.asStateFlow()

    private val _speechRate = MutableStateFlow(1.0f)
    val speechRate: StateFlow<Float> = _speechRate.asStateFlow()

    private val _pitch = MutableStateFlow(1.0f)
    val pitch: StateFlow<Float> = _pitch.asStateFlow()

    private val _selectedLanguage = MutableStateFlow(SpeechLanguage.JAPANESE)
    val selectedLanguage: StateFlow<SpeechLanguage> = _selectedLanguage.asStateFlow()

    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()

    private var tts: TextToSpeech? = null
    private val savedFileRepository = SavedFileRepository(application)
    private val completionTracker = SpeechCompletionTracker(
        application.getSharedPreferences(SpeechCompletionTracker.PREFS_NAME, Context.MODE_PRIVATE),
        AnalyticsClient.get(application),
    )

    /** 今読み上げている内容の出どころ（speech_completed の source。iOS と同じ値を使う） */
    @Volatile
    private var currentSource: String = SOURCE_TEXT

    /** 文単位の読み上げ位置。一時停止→再開はここから積み直す */
    private val queue = PlaybackQueue()
    private var currentTitle: String = ""

    /** 通知のボタン（停止・一時停止・再開）から届く操作 */
    private val controlReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                TtsNotificationService.BROADCAST_STOP -> stop()
                TtsNotificationService.BROADCAST_PAUSE -> pause()
                TtsNotificationService.BROADCAST_RESUME -> resume()
            }
        }
    }

    init {
        initTts()
        registerStopReceiver()
    }

    /** Retry TTS initialization after ERROR state */
    fun retryInit() {
        if (_state.value != TtsState.ERROR) return
        tts?.shutdown()
        tts = null
        _state.value = TtsState.IDLE
        _isInitialized.value = false
        initTts()
    }

    private fun registerStopReceiver() {
        val filter = IntentFilter().apply {
            addAction(TtsNotificationService.BROADCAST_STOP)
            addAction(TtsNotificationService.BROADCAST_PAUSE)
            addAction(TtsNotificationService.BROADCAST_RESUME)
        }
        ContextCompat.registerReceiver(
            getApplication(),
            controlReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun initTts() {
        tts = TextToSpeech(getApplication()) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        // 一時停止・停止の後に古い文のコールバックが来ても状態を戻さない
                        if (synchronized(queue) { queue.onChunkStarted(utteranceId) }) {
                            _state.value = TtsState.SPEAKING
                        }
                    }

                    override fun onDone(utteranceId: String?) {
                        // 最後の文を読み終えたときだけ完了。stop()/pause() で止めた場合は onStop が呼ばれここには来ない
                        if (synchronized(queue) { queue.isFinished(utteranceId) }) {
                            synchronized(queue) { queue.clear() }
                            _state.value = TtsState.IDLE
                            stopNotificationService()
                            completionTracker.onSpeechCompleted(currentSource)
                        }
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        _state.value = TtsState.ERROR
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        _state.value = TtsState.ERROR
                    }
                })
                applyLanguage(_selectedLanguage.value)
                _isInitialized.value = true
            } else {
                _state.value = TtsState.ERROR
            }
        }
    }

    fun speak(text: String, source: String = SOURCE_TEXT) {
        if (text.isBlank() || !_isInitialized.value) return
        currentSource = source
        currentTitle = text.take(60)
        val chunks = synchronized(queue) { queue.start(text, maxChunkLength()) }
        enqueue(chunks)
        saveToHistory(text)
        startNotificationService(currentTitle, isPlaying = true)
    }

    /** 今読んでいる文の頭で止める。再開すると同じ文の頭から読む */
    fun pause() {
        if (_state.value != TtsState.SPEAKING) return
        // 先にセッションを変えて、stop() の後に遅れて届く onStart で SPEAKING に戻らないようにする
        synchronized(queue) { queue.pause() }
        _state.value = TtsState.PAUSED
        tts?.stop()
        startNotificationService(currentTitle, isPlaying = false)
    }

    fun resume() {
        if (_state.value != TtsState.PAUSED) return
        val chunks = synchronized(queue) { queue.resume() }
        if (chunks.isEmpty()) {
            stop()
            return
        }
        _state.value = TtsState.SPEAKING
        enqueue(chunks)
        startNotificationService(currentTitle, isPlaying = true)
    }

    fun stop() {
        synchronized(queue) { queue.clear() }
        tts?.stop()
        _state.value = TtsState.IDLE
        stopNotificationService()
    }

    private fun enqueue(chunks: List<Pair<String, String>>) {
        tts?.setSpeechRate(_speechRate.value)
        chunks.forEachIndexed { i, (utteranceId, chunk) ->
            val mode = if (i == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
            tts?.speak(chunk, mode, null, utteranceId)
        }
    }

    private fun maxChunkLength(): Int =
        minOf(SpeechChunker.DEFAULT_MAX_LENGTH, TextToSpeech.getMaxSpeechInputLength())

    private fun startNotificationService(title: String, isPlaying: Boolean) {
        val intent = Intent(getApplication(), TtsNotificationService::class.java).apply {
            putExtra(TtsNotificationService.EXTRA_TITLE, title)
            putExtra(TtsNotificationService.EXTRA_IS_PLAYING, isPlaying)
        }
        ContextCompat.startForegroundService(getApplication(), intent)
    }

    private fun stopNotificationService() {
        getApplication<Application>().stopService(
            Intent(getApplication(), TtsNotificationService::class.java)
        )
    }

    fun setSpeechRate(rate: Float) {
        _speechRate.value = rate
        tts?.setSpeechRate(rate)
    }

    fun setPitch(pitch: Float) {
        _pitch.value = pitch
        tts?.setPitch(pitch)
    }

    fun setLanguage(language: SpeechLanguage) {
        _selectedLanguage.value = language
        applyLanguage(language)
    }

    private fun saveToHistory(text: String) {
        viewModelScope.launch {
            savedFileRepository.saveOrTouch(text, title = null, sourceType = SourceType.TYPED)
        }
    }

    fun saveImportedFile(title: String, content: String, sourceType: SourceType) {
        viewModelScope.launch {
            savedFileRepository.saveOrTouch(content, title = title, sourceType = sourceType)
        }
    }

    private fun applyLanguage(language: SpeechLanguage) {
        val result = tts?.setLanguage(language.locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            tts?.setLanguage(Locale.getDefault())
        }
    }

    companion object {
        const val SOURCE_TEXT = "text"
        const val SOURCE_PDF = "pdf"
    }

    override fun onCleared() {
        super.onCleared()
        runCatching { getApplication<Application>().unregisterReceiver(controlReceiver) }
        tts?.stop()
        tts?.shutdown()
        tts = null
        stopNotificationService()
    }
}
