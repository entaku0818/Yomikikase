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
    data class Loaded(val pages: List<PdfPage>) : PdfState()
    data class Error(val message: String) : PdfState()
}

class PdfViewModel(application: Application) : AndroidViewModel(application) {

    private val _state = MutableStateFlow<PdfState>(PdfState.Empty)
    val state: StateFlow<PdfState> = _state.asStateFlow()

    fun loadPdf(context: Context, uri: Uri) {
        viewModelScope.launch {
            _state.value = PdfState.Loading
            PdfRenderer.renderPages(context, uri)
                .onSuccess { pages ->
                    _state.value = if (pages.isEmpty()) {
                        PdfState.Error("PDFにページが見つかりませんでした")
                    } else {
                        PdfState.Loaded(pages)
                    }
                }
                .onFailure { error ->
                    _state.value = PdfState.Error(error.message ?: "不明なエラー")
                }
        }
    }
}
