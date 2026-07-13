package com.entaku.VoiceYourText.file

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class MyFilesFilter {
    ALL, TEXT, LINK;

    fun matches(sourceType: SourceType): Boolean = when (this) {
        ALL -> true
        TEXT -> sourceType == SourceType.TYPED || sourceType == SourceType.TXT_IMPORT
        LINK -> sourceType == SourceType.LINK
    }
}

class MyFilesViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SavedFileRepository(application)

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _filter = MutableStateFlow(MyFilesFilter.ALL)
    val filter: StateFlow<MyFilesFilter> = _filter.asStateFlow()

    val filteredFiles: StateFlow<List<SavedFileEntity>> = combine(
        repository.getAll(),
        _searchQuery,
        _filter
    ) { files, query, filter ->
        files.filter { file ->
            filter.matches(file.sourceType) &&
                (query.isBlank() || file.title.contains(query, ignoreCase = true))
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setFilter(filter: MyFilesFilter) {
        _filter.value = filter
    }

    fun delete(id: String) {
        viewModelScope.launch { repository.delete(id) }
    }

    fun saveImportedFile(title: String, content: String, sourceType: SourceType) {
        viewModelScope.launch { repository.saveOrTouch(content, title, sourceType) }
    }
}
