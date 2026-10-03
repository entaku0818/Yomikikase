package com.entaku.VoiceYourText.file

import android.content.Context
import kotlinx.coroutines.flow.Flow
import java.util.UUID

private const val AUTO_TITLE_LENGTH = 20

/** ゴミ箱の保持期間（iOS と同じ7日） */
const val TRASH_RETENTION_DAYS = 7
const val TRASH_RETENTION_MILLIS = TRASH_RETENTION_DAYS * 24L * 60 * 60 * 1000

/** ゴミ箱に入れてから完全に削除されるまでの残り日数（切り上げ。0 未満にはしない） */
fun trashDaysRemaining(deletedAt: Long, now: Long): Int {
    val remaining = deletedAt + TRASH_RETENTION_MILLIS - now
    if (remaining <= 0) return 0
    return ((remaining + 24L * 60 * 60 * 1000 - 1) / (24L * 60 * 60 * 1000)).toInt()
}

/** contentが既存行と一致すれば更新日時のみ更新し、なければ新規保存する。 */
suspend fun SavedFileDao.saveOrTouch(
    content: String,
    title: String?,
    sourceType: SourceType,
    now: Long = System.currentTimeMillis()
): SavedFileEntity {
    val existing = findByContent(content)
    if (existing != null) {
        // ゴミ箱に入っていた同じ内容を開き直したら、ゴミ箱から戻す
        val touched = existing.copy(
            title = title ?: existing.title,
            updatedAt = now,
            deletedAt = null
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

    /** ゴミ箱に入れる（7日間は復元できる） */
    suspend fun delete(id: String, now: Long = System.currentTimeMillis()) = dao.moveToTrash(id, now)

    fun getDeleted(): Flow<List<SavedFileEntity>> = dao.getDeleted()

    suspend fun restore(id: String) = dao.restore(id)

    suspend fun deletePermanently(id: String) = dao.deleteById(id)

    /** 保持期間（7日）を過ぎたゴミ箱のファイルを消す */
    suspend fun purgeExpired(now: Long = System.currentTimeMillis()): Int =
        dao.purgeDeletedBefore(now - TRASH_RETENTION_MILLIS)
}
