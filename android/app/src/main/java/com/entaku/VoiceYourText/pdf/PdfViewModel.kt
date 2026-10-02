package com.entaku.VoiceYourText.pdf

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed class PdfState {
    data object Empty : PdfState()
    data object Loading : PdfState()

    /** text はページ順の本文（画像だけの PDF なら空）、title は端末上のファイル名 */
    data class Loaded(val renderer: PdfPageRenderer, val text: String, val title: String?) : PdfState() {
        val pageCount: Int get() = renderer.pageCount
    }

    data class Error(val message: String) : PdfState()
}

class PdfViewModel(application: Application) : AndroidViewModel(application) {

    private val _state = MutableStateFlow<PdfState>(PdfState.Empty)
    val state: StateFlow<PdfState> = _state.asStateFlow()

    fun loadPdf(context: Context, uri: Uri) {
        viewModelScope.launch {
            closeCurrent()
            _state.value = PdfState.Loading
            PdfPageRenderer.open(context, uri)
                .onSuccess { renderer ->
                    if (renderer.pageCount == 0) {
                        renderer.close()
                        _state.value = PdfState.Error("PDFにページが見つかりませんでした")
                        return@onSuccess
                    }
                    // 文字が取れなくても表示はできるので、失敗は空文字として扱う
                    val text = PdfTextReader.read(context, uri).getOrDefault("")
                    _state.value = PdfState.Loaded(renderer, text, PdfTextReader.displayName(context, uri))
                }
                .onFailure { error ->
                    _state.value = PdfState.Error(error.message ?: "不明なエラー")
                }
        }
    }

    private fun closeCurrent() {
        (_state.value as? PdfState.Loaded)?.renderer?.close()
    }

    override fun onCleared() {
        super.onCleared()
        closeCurrent()
    }
}
