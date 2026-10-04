package com.entaku.VoiceYourText

import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory

/**
 * デバッグビルドはデバッグ用の App Check を使う。初回起動時に logcat（DebugAppCheckProvider）へ
 * デバッグトークンが出るので、Firebase コンソールの App Check に登録するとキャラ音声を試せる。
 */
object AppCheckSetup {
    fun install() {
        FirebaseAppCheck.getInstance().installAppCheckProviderFactory(DebugAppCheckProviderFactory.getInstance())
    }
}
