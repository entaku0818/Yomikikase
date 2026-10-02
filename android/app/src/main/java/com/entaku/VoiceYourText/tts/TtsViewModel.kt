package com.entaku.VoiceYourText.tts

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.entaku.VoiceYourText.analytics.SpeechCompletionTracker
import com.entaku.VoiceYourText.file.SavedFileRepository
import com.entaku.VoiceYourText.file.SourceType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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
    /** 保存・iOS との対応に使う言語コード（"ja", "en" など） */
    val code: String get() = locale.language

    companion object {
        val JAPANESE = SpeechLanguage(Locale.JAPANESE, "日本語")
        val ENGLISH = SpeechLanguage(Locale.ENGLISH, "English")
        val CHINESE = SpeechLanguage(Locale.CHINESE, "中文")
        val KOREAN = SpeechLanguage(Locale.KOREAN, "한국어")
        val FRENCH = SpeechLanguage(Locale.FRENCH, "Français")
        val GERMAN = SpeechLanguage(Locale.GERMAN, "Deutsch")
        val SPANISH = SpeechLanguage(Locale("es"), "Español")
        val ITALIAN = SpeechLanguage(Locale.ITALIAN, "Italiano")
        val PORTUGUESE = SpeechLanguage(Locale("pt"), "Português")
        val RUSSIAN = SpeechLanguage(Locale("ru"), "Русский")
        val TURKISH = SpeechLanguage(Locale("tr"), "Türkçe")
        val VIETNAMESE = SpeechLanguage(Locale("vi"), "Tiếng Việt")
        val THAI = SpeechLanguage(Locale("th"), "ไทย")

        /** iOS（Setting.swift の availableLanguages）と同じ13言語 */
        val ALL = listOf(
            JAPANESE, ENGLISH, CHINESE, KOREAN, FRENCH, GERMAN, SPANISH,
            ITALIAN, PORTUGUESE, RUSSIAN, TURKISH, VIETNAMESE, THAI,
        )

        fun fromCode(code: String?): SpeechLanguage? = ALL.firstOrNull { it.code == code }
    }
}

/** ミニプレイヤーに出す再生中の情報。source は "text" / "pdf"（戻り先の画面を決める） */
data class NowPlaying(val title: String, val source: String)

/** 読み上げ中の箇所。text は読み上げを始めた元のテキスト、range はその上の範囲 */
data class SpeechHighlight(val text: String, val range: TextRange, val source: String)

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

    /** 選んだ言語の音声データが端末に無く、既定の言語で代わりに読んでいるとき true */
    private val _isLanguageUnavailable = MutableStateFlow(false)
    val isLanguageUnavailable: StateFlow<Boolean> = _isLanguageUnavailable.asStateFlow()

    private val settingsPrefs = application.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)

    /** 読み上げ画面の入力欄の内容。画面（タブ）を移っても残す */
    private val _draftText = MutableStateFlow("")
    val draftText: StateFlow<String> = _draftText.asStateFlow()

    fun setDraftText(text: String) {
        _draftText.value = text
    }

    /** 再生中（一時停止中を含む）の内容。止めたら null */
    private val _nowPlaying = MutableStateFlow<NowPlaying?>(null)
    val nowPlaying: StateFlow<NowPlaying?> = _nowPlaying.asStateFlow()

    /** 読み上げ中の箇所（元のテキスト上の範囲）。止めたら null */
    private val _highlight = MutableStateFlow<SpeechHighlight?>(null)
    val highlight: StateFlow<SpeechHighlight?> = _highlight.asStateFlow()

    /** 今読んでいるテキストの整形結果（読み上げ用テキスト→元テキストの位置の逆引きに使う） */
    @Volatile
    private var prepared: PreparedSpeechText? = null

    private val _sleepTimer = MutableStateFlow<SleepTimerState?>(null)
    val sleepTimer: StateFlow<SleepTimerState?> = _sleepTimer.asStateFlow()
    private var sleepTimerJob: Job? = null

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
        // 前回選んだ言語を復元する（以前は起動のたびに日本語に戻っていた）
        SpeechLanguage.fromCode(settingsPrefs.getString(KEY_LANGUAGE, null))?.let { _selectedLanguage.value = it }
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

                    override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                        val spoken = synchronized(queue) { queue.spokenRange(utteranceId, start, end) } ?: return
                        val current = prepared ?: return
                        val range = current.originalRange(spoken) ?: return
                        _highlight.value = SpeechHighlight(current.original, range, currentSource)
                    }

                    override fun onDone(utteranceId: String?) {
                        // 最後の文を読み終えたときだけ完了。stop()/pause() で止めた場合は onStop が呼ばれここには来ない
                        if (synchronized(queue) { queue.isFinished(utteranceId) }) {
                            synchronized(queue) { queue.clear() }
                            _state.value = TtsState.IDLE
                            _highlight.value = null
                            _nowPlaying.value = null
                            stopNotificationService()
                            // 読み終えたら「文章の終わりで停止」も含めてタイマーは役目を終える
                            setSleepTimer(null)
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

    /**
     * @param source speech_completed の source（"text" / "pdf"）
     * @param title マイファイルに保存するときのタイトル（null なら本文から自動生成）
     * @param saveAs マイファイルに保存するときの種類
     * @param saveText マイファイルに保存する本文（途中から読むときも全文を保存するため）
     */
    fun speak(
        text: String,
        source: String = SOURCE_TEXT,
        title: String? = null,
        saveAs: SourceType = SourceType.TYPED,
        saveText: String = text,
    ) {
        if (text.isBlank() || !_isInitialized.value) return
        currentSource = source
        currentTitle = text.take(60)
        // 英略語・単位・折り返し改行などを読みやすく整えてから読む（iOS と同じルール）
        val preparedText = SpeechTextPreprocessor.prepare(text, _selectedLanguage.value.locale.language)
        prepared = preparedText
        _highlight.value = null
        _nowPlaying.value = NowPlaying(title ?: currentTitle.lineSequence().first().take(40), source)
        val chunks = synchronized(queue) { queue.start(preparedText.spoken, maxChunkLength()) }
        enqueue(chunks)
        saveToHistory(saveText, title, saveAs)
        startNotificationService(title ?: currentTitle, isPlaying = true)
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

    /**
     * スリープタイマーを設定する（null で解除）。時間指定は0になったら一時停止する
     * （iOS と同じく、あとで再開できるよう停止ではなく一時停止にする）。
     * 読み上げ中はフォアグラウンドサービスでプロセスが生きているので、画面オフでもカウントは進む。
     */
    fun setSleepTimer(option: SleepTimerOption?) {
        sleepTimerJob?.cancel()
        sleepTimerJob = null
        if (option == null) {
            _sleepTimer.value = null
            return
        }
        _sleepTimer.value = SleepTimerState(option)
        if (option.totalSeconds == null) return
        sleepTimerJob = viewModelScope.launch {
            while (true) {
                delay(1_000)
                val next = _sleepTimer.value?.ticked() ?: return@launch
                _sleepTimer.value = next
                if (next.isExpired) {
                    _sleepTimer.value = null
                    pause()
                    return@launch
                }
            }
        }
    }

    fun stop() {
        setSleepTimer(null)
        synchronized(queue) { queue.clear() }
        tts?.stop()
        _state.value = TtsState.IDLE
        _highlight.value = null
        _nowPlaying.value = null
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
        settingsPrefs.edit { putString(KEY_LANGUAGE, language.code) }
        applyLanguage(language)
    }

    private fun saveToHistory(text: String, title: String?, sourceType: SourceType) {
        viewModelScope.launch {
            savedFileRepository.saveOrTouch(text, title = title, sourceType = sourceType)
        }
    }

    fun saveImportedFile(title: String, content: String, sourceType: SourceType) {
        viewModelScope.launch {
            savedFileRepository.saveOrTouch(content, title = title, sourceType = sourceType)
        }
    }

    private fun applyLanguage(language: SpeechLanguage) {
        val result = tts?.setLanguage(language.locale) ?: return
        val unavailable = result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED
        _isLanguageUnavailable.value = unavailable
        if (unavailable) {
            tts?.setLanguage(Locale.getDefault())
        }
    }

    companion object {
        const val SOURCE_TEXT = "text"
        const val SOURCE_PDF = "pdf"
        private const val SETTINGS_PREFS = "tts_settings"
        private const val KEY_LANGUAGE = "speech_language"
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
