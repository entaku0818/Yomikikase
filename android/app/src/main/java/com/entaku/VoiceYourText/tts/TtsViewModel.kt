package com.entaku.VoiceYourText.tts

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale
import java.util.UUID

enum class TtsState {
    IDLE, SPEAKING, ERROR
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

    private val _history = MutableStateFlow<List<String>>(emptyList())
    val history: StateFlow<List<String>> = _history.asStateFlow()

    private var tts: TextToSpeech? = null
    private val historyStore = HistoryStore(application)

    /** BroadcastReceiver: receives TTS_STOP from TtsNotificationService stop button */
    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.entaku.VoiceYourText.TTS_STOP") {
                stop()
            }
        }
    }

    init {
        _history.value = historyStore.getAll()
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
        val filter = IntentFilter("com.entaku.VoiceYourText.TTS_STOP")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getApplication<Application>().registerReceiver(stopReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            getApplication<Application>().registerReceiver(stopReceiver, filter)
        }
    }

    private fun initTts() {
        tts = TextToSpeech(getApplication()) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        _state.value = TtsState.SPEAKING
                    }

                    override fun onDone(utteranceId: String?) {
                        _state.value = TtsState.IDLE
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

    fun speak(text: String) {
        if (text.isBlank() || !_isInitialized.value) return
        tts?.setSpeechRate(_speechRate.value)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
        saveToHistory(text)
        startNotificationService(text.take(60))
    }

    fun stop() {
        tts?.stop()
        _state.value = TtsState.IDLE
        stopNotificationService()
    }

    private fun startNotificationService(title: String) {
        val intent = Intent(getApplication(), TtsNotificationService::class.java).apply {
            putExtra(TtsNotificationService.EXTRA_TITLE, title)
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

    fun deleteHistory(text: String) {
        historyStore.delete(text)
        _history.value = historyStore.getAll()
    }

    private fun saveToHistory(text: String) {
        historyStore.save(text)
        _history.value = historyStore.getAll()
    }

    private fun applyLanguage(language: SpeechLanguage) {
        val result = tts?.setLanguage(language.locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            tts?.setLanguage(Locale.getDefault())
        }
    }

    override fun onCleared() {
        super.onCleared()
        runCatching { getApplication<Application>().unregisterReceiver(stopReceiver) }
        tts?.stop()
        tts?.shutdown()
        tts = null
        stopNotificationService()
    }
}
