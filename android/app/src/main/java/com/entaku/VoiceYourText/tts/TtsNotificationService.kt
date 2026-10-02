package com.entaku.VoiceYourText.tts

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.IBinder
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.entaku.VoiceYourText.MainActivity
import com.entaku.VoiceYourText.R

class TtsNotificationService : Service() {

    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var notificationManager: NotificationManager

    companion object {
        const val CHANNEL_ID = "tts_playback"
        const val NOTIFICATION_ID = 1
        const val ACTION_STOP = "com.entaku.VoiceYourText.ACTION_STOP"
        const val ACTION_PAUSE = "com.entaku.VoiceYourText.ACTION_PAUSE"
        const val ACTION_RESUME = "com.entaku.VoiceYourText.ACTION_RESUME"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_IS_PLAYING = "extra_is_playing"

        /** 通知の操作を TtsViewModel に伝えるブロードキャスト（アプリ内のみ） */
        const val BROADCAST_STOP = "com.entaku.VoiceYourText.TTS_STOP"
        const val BROADCAST_PAUSE = "com.entaku.VoiceYourText.TTS_PAUSE"
        const val BROADCAST_RESUME = "com.entaku.VoiceYourText.TTS_RESUME"
    }

    private fun sendControl(action: String) {
        sendBroadcast(Intent(action).setPackage(packageName))
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(NotificationManager::class.java)
        createNotificationChannel()
        setupMediaSession()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                sendControl(BROADCAST_STOP)
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                sendControl(BROADCAST_PAUSE)
                return START_NOT_STICKY
            }
            ACTION_RESUME -> {
                sendControl(BROADCAST_RESUME)
                return START_NOT_STICKY
            }
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "読み上げ中"
        val isPlaying = intent?.getBooleanExtra(EXTRA_IS_PLAYING, true) ?: true
        startForeground(NOTIFICATION_ID, buildNotification(title, isPlaying))
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        mediaSession.release()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "読み上げ再生",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "テキスト読み上げの再生コントロール"
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun setupMediaSession() {
        mediaSession = MediaSessionCompat(this, "VoiceYourText").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onStop() {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    sendControl(BROADCAST_STOP)
                }

                override fun onPause() {
                    sendControl(BROADCAST_PAUSE)
                }

                override fun onPlay() {
                    sendControl(BROADCAST_RESUME)
                }
            })
            isActive = true
        }
    }

    private fun buildNotification(title: String, isPlaying: Boolean): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getService(
            this,
            0,
            Intent(this, TtsNotificationService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, TtsNotificationService::class.java).apply {
                action = if (isPlaying) ACTION_PAUSE else ACTION_RESUME
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .setActions(
                    PlaybackStateCompat.ACTION_STOP or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE
                )
                .build()
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Voice Your Text")
            .setContentText(title)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(contentIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "一時停止" else "再開",
                toggleIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "停止",
                stopIntent
            )
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }
}
