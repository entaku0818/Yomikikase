package com.entaku.VoiceYourText.voicevox

import java.io.File
import java.security.MessageDigest
import java.util.Locale

/**
 * キャラ音声で作った音声を端末に保存する（iOS VoicevoxAudioCache と同じ考え方）。
 *
 * 同じ文・同じ声・同じ速度なら保存済みの音声を再生し、サーバーを呼ばない（＝月の文字数を使わない）。
 * キャッシュ領域に置くので、端末の空き容量が少ないと OS に消されることがある（そのときは作り直す）。
 */
class VoicevoxAudioCache(private val directory: File) {

    fun file(text: String, speakerId: Int, speedScale: Double): File =
        File(directory, key(text, speakerId, speedScale) + ".m4a")

    fun load(text: String, speakerId: Int, speedScale: Double): File? =
        file(text, speakerId, speedScale).takeIf { it.isFile && it.length() > 0 }

    /** 保存したファイルを返す。書けなかったら例外（再生側で一時ファイルとして扱う） */
    fun store(data: ByteArray, text: String, speakerId: Int, speedScale: Double): File {
        directory.mkdirs()
        val target = file(text, speakerId, speedScale)
        val temp = File(directory, target.name + ".tmp")
        temp.writeBytes(data)
        if (!temp.renameTo(target)) {
            temp.delete()
            throw java.io.IOException("cache rename failed")
        }
        return target
    }

    fun totalSize(): Long = directory.listFiles()?.sumOf { it.length() } ?: 0L

    fun removeAll() {
        directory.deleteRecursively()
    }

    companion object {
        fun key(text: String, speakerId: Int, speedScale: Double): String {
            // 速度は小数第2位まで（iOS と同じ）
            val material = "$speakerId|${String.format(Locale.US, "%.2f", speedScale)}|$text"
            return MessageDigest.getInstance("SHA-256").digest(material.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }
}
