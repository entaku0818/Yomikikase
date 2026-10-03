package com.entaku.VoiceYourText.file

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

private class FakeSavedFileDao : SavedFileDao {
    private val state = MutableStateFlow<List<SavedFileEntity>>(emptyList())

    fun snapshot(): List<SavedFileEntity> = state.value

    override fun getAll(): Flow<List<SavedFileEntity>> = state.map { list -> list.filter { it.deletedAt == null } }

    override fun getDeleted(): Flow<List<SavedFileEntity>> = state.map { list -> list.filter { it.deletedAt != null } }

    override suspend fun moveToTrash(id: String, now: Long) {
        state.value = state.value.map { if (it.id == id) it.copy(deletedAt = now) else it }
    }

    override suspend fun restore(id: String) {
        state.value = state.value.map { if (it.id == id) it.copy(deletedAt = null) else it }
    }

    override suspend fun purgeDeletedBefore(before: Long): Int {
        val (expired, kept) = state.value.partition { it.deletedAt != null && it.deletedAt < before }
        state.value = kept
        return expired.size
    }

    override suspend fun findByContent(content: String): SavedFileEntity? =
        state.value.firstOrNull { it.content == content }

    override suspend fun getMostRecent(): SavedFileEntity? =
        state.value.maxByOrNull { it.updatedAt }

    override suspend fun insert(entity: SavedFileEntity) {
        state.value = state.value + entity
    }

    override suspend fun update(entity: SavedFileEntity) {
        state.value = state.value.map { if (it.id == entity.id) entity else it }
    }

    override suspend fun deleteById(id: String) {
        state.value = state.value.filterNot { it.id == id }
    }
}

class SavedFileRepositoryTest {

    @Test
    fun `saveOrTouch inserts a new entity when content is new`() = runBlocking {
        val dao = FakeSavedFileDao()

        val saved = dao.saveOrTouch("hello world", title = null, sourceType = SourceType.TYPED, now = 100L)

        assertEquals("hello world", saved.content)
        assertEquals(SourceType.TYPED, saved.sourceType)
        assertEquals(100L, saved.createdAt)
    }

    @Test
    fun `saveOrTouch updates updatedAt instead of duplicating when content matches`() = runBlocking {
        val dao = FakeSavedFileDao()
        val first = dao.saveOrTouch("same text", title = null, sourceType = SourceType.TYPED, now = 100L)

        val second = dao.saveOrTouch("same text", title = null, sourceType = SourceType.TYPED, now = 200L)

        assertEquals(first.id, second.id)
        assertEquals(200L, second.updatedAt)
        assertEquals(1, dao.snapshot().size)
    }

    @Test
    fun `saveOrTouch auto-generates a title from content when none is given`() = runBlocking {
        val dao = FakeSavedFileDao()

        val saved = dao.saveOrTouch(
            "this is a fairly long piece of text that should be truncated",
            title = null,
            sourceType = SourceType.TYPED,
            now = 100L
        )

        assertEquals("this is a fairly lon…", saved.title)
    }

    @Test
    fun `saveOrTouch keeps a short title untruncated`() = runBlocking {
        val dao = FakeSavedFileDao()

        val saved = dao.saveOrTouch("short", title = null, sourceType = SourceType.TYPED, now = 100L)

        assertEquals("short", saved.title)
    }

    @Test
    fun `saveOrTouch uses the given title over auto-generated title`() = runBlocking {
        val dao = FakeSavedFileDao()

        val saved = dao.saveOrTouch("some content", title = "my-file.txt", sourceType = SourceType.TXT_IMPORT, now = 100L)

        assertEquals("my-file.txt", saved.title)
        assertEquals(SourceType.TXT_IMPORT, saved.sourceType)
    }

    @Test
    fun `deleteById removes the entity`() = runBlocking {
        val dao = FakeSavedFileDao()
        val saved = dao.saveOrTouch("to be deleted", title = null, sourceType = SourceType.TYPED, now = 100L)
        assertNotEquals(0, dao.snapshot().size)

        dao.deleteById(saved.id)

        assertNull(dao.findByContent("to be deleted"))
    }

    @Test
    fun ゴミ箱に入れたファイルは一覧から消え7日を過ぎると完全に消える() = runBlocking {
        val dao = FakeSavedFileDao()
        val day = 24L * 60 * 60 * 1000
        val saved = dao.saveOrTouch("本文", title = "メモ", sourceType = SourceType.TYPED, now = 0L)

        dao.moveToTrash(saved.id, now = 0L)
        assertEquals(emptyList<SavedFileEntity>(), dao.getAll().first())
        assertEquals(listOf(saved.id), dao.getDeleted().first().map { it.id })

        assertEquals(0, dao.purgeDeletedBefore(6 * day - TRASH_RETENTION_MILLIS))
        assertEquals(1, dao.purgeDeletedBefore(8 * day - TRASH_RETENTION_MILLIS))
        assertEquals(emptyList<SavedFileEntity>(), dao.snapshot())
    }

    @Test
    fun ゴミ箱の中と同じ内容を開き直したらゴミ箱から戻る() = runBlocking {
        val dao = FakeSavedFileDao()
        val saved = dao.saveOrTouch("本文", title = "メモ", sourceType = SourceType.TYPED, now = 0L)
        dao.moveToTrash(saved.id, now = 1L)

        dao.saveOrTouch("本文", title = null, sourceType = SourceType.TYPED, now = 2L)

        assertEquals(listOf(saved.id), dao.getAll().first().map { it.id })
        assertNull(dao.snapshot().single().deletedAt)
    }
}
