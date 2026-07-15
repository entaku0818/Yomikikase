package com.entaku.VoiceYourText.file

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MyFilesFilterTest {

    @Test
    fun `ALL matches every source type`() {
        SourceType.entries.forEach { sourceType ->
            assertTrue(MyFilesFilter.ALL.matches(sourceType))
        }
    }

    @Test
    fun `TEXT matches TYPED and TXT_IMPORT but not LINK`() {
        assertTrue(MyFilesFilter.TEXT.matches(SourceType.TYPED))
        assertTrue(MyFilesFilter.TEXT.matches(SourceType.TXT_IMPORT))
        assertFalse(MyFilesFilter.TEXT.matches(SourceType.LINK))
    }

    @Test
    fun `LINK matches only LINK`() {
        assertTrue(MyFilesFilter.LINK.matches(SourceType.LINK))
        assertFalse(MyFilesFilter.LINK.matches(SourceType.TYPED))
        assertFalse(MyFilesFilter.LINK.matches(SourceType.TXT_IMPORT))
    }

    private fun file(title: String, sourceType: SourceType) = SavedFileEntity(
        id = title,
        title = title,
        content = "content of $title",
        sourceType = sourceType,
        createdAt = 0L,
        updatedAt = 0L
    )

    @Test
    fun `filterFiles with ALL and blank query returns every file`() {
        val files = listOf(
            file("typed", SourceType.TYPED),
            file("imported", SourceType.TXT_IMPORT),
            file("linked", SourceType.LINK)
        )

        val result = filterFiles(files, query = "", filter = MyFilesFilter.ALL)

        assertEquals(files, result)
    }

    @Test
    fun `filterFiles with TEXT filter excludes LINK entries`() {
        val files = listOf(
            file("typed", SourceType.TYPED),
            file("imported", SourceType.TXT_IMPORT),
            file("linked", SourceType.LINK)
        )

        val result = filterFiles(files, query = "", filter = MyFilesFilter.TEXT)

        assertEquals(listOf(files[0], files[1]), result)
    }

    @Test
    fun `filterFiles with LINK filter keeps only LINK entries`() {
        val files = listOf(
            file("typed", SourceType.TYPED),
            file("imported", SourceType.TXT_IMPORT),
            file("linked", SourceType.LINK)
        )

        val result = filterFiles(files, query = "", filter = MyFilesFilter.LINK)

        assertEquals(listOf(files[2]), result)
    }

    @Test
    fun `filterFiles applies a case-insensitive search query`() {
        val files = listOf(
            file("Morning News", SourceType.TYPED),
            file("evening memo", SourceType.TXT_IMPORT)
        )

        val result = filterFiles(files, query = "MORNING", filter = MyFilesFilter.ALL)

        assertEquals(listOf(files[0]), result)
    }

    @Test
    fun `filterFiles combines filter and search query with AND`() {
        val files = listOf(
            file("Morning link", SourceType.LINK),
            file("Morning memo", SourceType.TYPED)
        )

        val result = filterFiles(files, query = "morning", filter = MyFilesFilter.LINK)

        assertEquals(listOf(files[0]), result)
    }

    @Test
    fun `filterFiles returns nothing when search query matches no title`() {
        val files = listOf(file("Morning News", SourceType.TYPED))

        val result = filterFiles(files, query = "nonexistent", filter = MyFilesFilter.ALL)

        assertTrue(result.isEmpty())
    }
}
