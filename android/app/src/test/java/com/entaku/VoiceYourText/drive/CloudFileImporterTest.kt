package com.entaku.VoiceYourText.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CloudFileImporterTest {
    @Test
    fun prefersPlainTextExport() {
        assertEquals(
            "text/plain",
            CloudFileImporter.exportType(listOf("application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain")),
        )
    }

    @Test
    fun fallsBackToOtherTextThenPdf() {
        assertEquals("text/html", CloudFileImporter.exportType(listOf("application/pdf", "text/html")))
        assertEquals("application/pdf", CloudFileImporter.exportType(listOf("application/rtf", "application/pdf")))
    }

    @Test
    fun noReadableExport() {
        assertNull(CloudFileImporter.exportType(listOf("image/png")))
        assertNull(CloudFileImporter.exportType(emptyList()))
    }
}
