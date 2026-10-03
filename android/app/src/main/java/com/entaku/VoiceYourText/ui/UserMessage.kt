package com.entaku.VoiceYourText.ui

import android.content.Context
import androidx.annotation.StringRes

/**
 * 画面に出すメッセージを文字列リソースで持つ例外。
 * 画面の外（読み込み処理など）で作るエラーも、表示するときに端末の言語に翻訳できるようにする。
 */
class UserMessageException(@StringRes val messageRes: Int, vararg val args: Any) : Exception()

/** 表示用のメッセージ。UserMessageException なら翻訳済みの文言、それ以外は例外のメッセージか fallback */
fun Throwable.userMessage(context: Context, @StringRes fallback: Int): String = when (this) {
    is UserMessageException -> context.getString(messageRes, *args)
    else -> message?.takeIf { it.isNotBlank() } ?: context.getString(fallback)
}

/** 端末の言語に合わせた「月日」の書式（日本語なら「10月3日」、英語なら「Oct 3」） */
fun localizedMonthDayFormat(locale: java.util.Locale = java.util.Locale.getDefault()): java.text.DateFormat =
    java.text.SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMd"), locale)
