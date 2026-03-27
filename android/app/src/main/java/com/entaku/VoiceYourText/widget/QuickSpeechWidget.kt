package com.entaku.VoiceYourText.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.entaku.VoiceYourText.MainActivity
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.tts.HistoryStore

class QuickSpeechWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_speech)

            // Show latest history item if available
            val history = HistoryStore(context).getAll()
            val label = if (history.isNotEmpty()) {
                history.first().take(30)
            } else {
                context.getString(R.string.widget_tap_to_open)
            }
            views.setTextViewText(R.id.widget_label, label)

            // Tap to open main app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_open_button, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_label, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
