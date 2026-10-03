package com.entaku.VoiceYourText.billing

import android.content.Context
import androidx.core.content.edit
import com.entaku.VoiceYourText.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.getCustomerInfoWith
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * プレミアム（サブスク）状態。iOS と同じ RevenueCat プロジェクト・特典 `premium` を使う。
 * 起動直後から広告の出し分けに使えるよう、最後に分かった状態を端末に保存しておく。
 */
object PremiumManager {
    const val ENTITLEMENT = "premium"
    private const val PREFS = "premium"
    private const val KEY_IS_PREMIUM = "is_premium"

    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    /** RevenueCat のキーが入っているか（無いビルドでは課金画面を出さない） */
    val isAvailable: Boolean get() = BuildConfig.REVENUECAT_API_KEY.isNotBlank()

    @Volatile
    private var configured = false

    fun configure(context: Context) {
        val app = context.applicationContext
        _isPremium.value = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_IS_PREMIUM, false)
        if (!isAvailable || configured) return
        configured = true
        Purchases.configure(PurchasesConfiguration.Builder(app, BuildConfig.REVENUECAT_API_KEY).build())
        Purchases.sharedInstance.updatedCustomerInfoListener =
            com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener { update(app, it) }
        Purchases.sharedInstance.getCustomerInfoWith(onSuccess = { update(app, it) })
    }

    fun update(context: Context, info: CustomerInfo) {
        val premium = info.entitlements[ENTITLEMENT]?.isActive == true
        _isPremium.value = premium
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(KEY_IS_PREMIUM, premium) }
    }
}

/** 無料版の上限（iOS FileLimitsManager と同じ5件） */
object FileLimits {
    const val MAX_FREE_FILES = 5

    fun hasReachedLimit(fileCount: Int, isPremium: Boolean): Boolean = !isPremium && fileCount >= MAX_FREE_FILES
}
