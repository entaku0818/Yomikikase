package com.entaku.VoiceYourText.file

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface SavedFileDao {
    @Query("SELECT * FROM saved_files WHERE deletedAt IS NULL ORDER BY updatedAt DESC")
    fun getAll(): Flow<List<SavedFileEntity>>

    @Query("SELECT * FROM saved_files WHERE deletedAt IS NOT NULL ORDER BY deletedAt DESC")
    fun getDeleted(): Flow<List<SavedFileEntity>>

    @Query("UPDATE saved_files SET deletedAt = :now WHERE id = :id")
    suspend fun moveToTrash(id: String, now: Long)

    @Query("UPDATE saved_files SET deletedAt = NULL WHERE id = :id")
    suspend fun restore(id: String)

    /** ゴミ箱に入れてから保持期間を過ぎたものを完全に削除する */
    @Query("DELETE FROM saved_files WHERE deletedAt IS NOT NULL AND deletedAt < :before")
    suspend fun purgeDeletedBefore(before: Long): Int

    @Query("SELECT * FROM saved_files WHERE content = :content LIMIT 1")
    suspend fun findByContent(content: String): SavedFileEntity?

    @Query("SELECT * FROM saved_files WHERE deletedAt IS NULL ORDER BY updatedAt DESC LIMIT 1")
    suspend fun getMostRecent(): SavedFileEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: SavedFileEntity)

    @Update
    suspend fun update(entity: SavedFileEntity)

    @Query("DELETE FROM saved_files WHERE id = :id")
    suspend fun deleteById(id: String)
}
