package com.entaku.VoiceYourText.file

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface SavedFileDao {
    @Query("SELECT * FROM saved_files ORDER BY updatedAt DESC")
    fun getAll(): Flow<List<SavedFileEntity>>

    @Query("SELECT * FROM saved_files WHERE content = :content LIMIT 1")
    suspend fun findByContent(content: String): SavedFileEntity?

    @Query("SELECT * FROM saved_files ORDER BY updatedAt DESC LIMIT 1")
    suspend fun getMostRecent(): SavedFileEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: SavedFileEntity)

    @Update
    suspend fun update(entity: SavedFileEntity)

    @Query("DELETE FROM saved_files WHERE id = :id")
    suspend fun deleteById(id: String)
}
