package com.entaku.VoiceYourText.file

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class SourceType {
    TYPED, TXT_IMPORT, LINK, PDF, EPUB, AOZORA, SCAN
}

@Entity(tableName = "saved_files")
data class SavedFileEntity(
    @PrimaryKey val id: String,
    val title: String,
    val content: String,
    val sourceType: SourceType,
    val createdAt: Long,
    val updatedAt: Long,
    /** ゴミ箱に入れた日時（null なら通常のファイル）。7日たったら完全に削除する（iOS と同じ） */
    val deletedAt: Long? = null,
)
