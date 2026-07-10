package com.entaku.VoiceYourText.file

import android.content.Context
import kotlinx.coroutines.flow.Flow
import java.util.UUID

private const val AUTO_TITLE_LENGTH = 20

/** contentが既存行と一致すれば更新日時のみ更新し、なければ新規保存する。 */
suspend fun SavedFileDao.saveOrTouch(
    content: String,
    title: String?,
    sourceType: SourceType,
    now: Long = System.currentTimeMillis()
): SavedFileEntity {
    val existing = findByContent(content)
    if (existing != null) {
        val touched = existing.copy(
            title = title ?: existing.title,
            updatedAt = now
        )
        update(touched)
        return touched
    }

    val entity = SavedFileEntity(
        id = UUID.randomUUID().toString(),
        title = title ?: autoTitle(content),
        content = content,
        sourceType = sourceType,
        createdAt = now,
        updatedAt = now
    )
    insert(entity)
    return entity
}

fun autoTitle(content: String): String {
    val trimmed = content.trim()
    return if (trimmed.length > AUTO_TITLE_LENGTH) {
        trimmed.take(AUTO_TITLE_LENGTH) + "…"
    } else {
        trimmed
    }
}

class SavedFileRepository(context: Context) {
    private val dao = AppDatabase.getInstance(context).savedFileDao()

    fun getAll(): Flow<List<SavedFileEntity>> = dao.getAll()

    suspend fun getMostRecent(): SavedFileEntity? = dao.getMostRecent()

    suspend fun saveOrTouch(content: String, title: String? = null, sourceType: SourceType = SourceType.TYPED): SavedFileEntity =
        dao.saveOrTouch(content, title, sourceType)

    suspend fun delete(id: String) = dao.deleteById(id)
}
