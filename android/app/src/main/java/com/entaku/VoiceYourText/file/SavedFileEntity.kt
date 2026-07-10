package com.entaku.VoiceYourText.file

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class SourceType {
    TYPED, TXT_IMPORT, LINK
}

@Entity(tableName = "saved_files")
data class SavedFileEntity(
    @PrimaryKey val id: String,
    val title: String,
    val content: String,
    val sourceType: SourceType,
    val createdAt: Long,
    val updatedAt: Long
)
