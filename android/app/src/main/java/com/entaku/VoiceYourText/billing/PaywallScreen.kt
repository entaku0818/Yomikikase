package com.entaku.VoiceYourText.billing

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.core.net.toUri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.entaku.VoiceYourText.R
import com.entaku.VoiceYourText.analytics.AnalyticsClient
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.models.Period
import kotlinx.coroutines.launch

private const val PRIVACY_URL = "https://voiceyourtext.web.app/privacy_policy.html"
private const val TERMS_URL = "https://voiceyourtext.web.app/terms_of_service.html"

/**
 * 課金画面（iOS `SubscriptionView` 相当）。月額・年額と7日間の無料トライアルを出す。
 * @param source どこから開いたか（paywall_view / subscription_view_opened の source。iOS と同じ）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallScreen(source: String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val analytics = remember { AnalyticsClient.get(context) }
    val scope = rememberCoroutineScope()
    var monthly by remember { mutableStateOf<Package?>(null) }
    var annual by remember { mutableStateOf<Package?>(null) }
    var selected by remember { mutableStateOf<Package?>(null) }
    var loading by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        analytics.logEvent("subscription_view_opened", mapOf("source" to source))
        analytics.logEvent("paywall_view", mapOf("source" to source))
        runCatching { Purchases.sharedInstance.awaitOfferings() }
            .onSuccess { offerings ->
                monthly = offerings.current?.monthly
                annual = offerings.current?.annual
                selected = annual ?: monthly
                if (monthly == null && annual == null) message = context.getString(R.string.paywall_loading_failed)
            }
            .onFailure {
                analytics.logEvent("subscription_plan_fetch_failed", mapOf("error" to (it.message ?: "").take(100)))
                message = context.getString(R.string.paywall_loading_failed)
            }
        loading = false
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = {},
                    navigationIcon = { IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, contentDescription = stringResource(R.string.common_close)) } }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(stringResource(R.string.paywall_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                listOf(R.string.paywall_benefit_no_ads, R.string.paywall_benefit_unlimited, R.string.paywall_benefit_support).forEach {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Text(stringResource(it), modifier = Modifier.padding(start = 8.dp))
                    }
                }

                if (loading) {
                    Box(Modifier.fillMaxWidth().height(160.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                } else {
                    annual?.let { pkg ->
                        PlanCard(
                            title = stringResource(R.string.paywall_annual),
                            price = stringResource(R.string.paywall_per_year, pkg.product.price.formatted),
                            badge = listOfNotNull(
                                trialDays(pkg)?.let { stringResource(R.string.paywall_free_trial, it) },
                                savingsPercent(monthly, pkg)?.let { stringResource(R.string.paywall_save, it) },
                            ).joinToString(" · ").ifEmpty { null },
                            selected = selected == pkg,
                            onClick = { selected = pkg },
                        )
                    }
                    monthly?.let { pkg ->
                        PlanCard(
                            title = stringResource(R.string.paywall_monthly),
                            price = stringResource(R.string.paywall_per_month, pkg.product.price.formatted),
                            badge = trialDays(pkg)?.let { stringResource(R.string.paywall_free_trial, it) },
                            selected = selected == pkg,
                            onClick = { selected = pkg },
                        )
                    }
                }

                message?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }

                val pkg = selected
                val hasTrial = pkg != null && trialDays(pkg) != null
                Button(
                    onClick = {
                        val activity = context.findActivity() ?: return@Button
                        busy = true
                        message = null
                        scope.launch {
                            runCatching { Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg!!).build()) }
                                .onSuccess { result ->
                                    PremiumManager.update(context, result.customerInfo)
                                    analytics.logEvent("subscription_purchase_success", mapOf("product_id" to pkg!!.product.id, "source" to source))
                                    message = context.getString(R.string.paywall_thanks)
                                    if (PremiumManager.isPremium.value) onDismiss()
                                }
                                .onFailure { e ->
                                    if (e is PurchasesTransactionException && e.userCancelled) {
                                        analytics.logEvent("subscription_purchase_cancelled")
                                    } else {
                                        analytics.logEvent("subscription_purchase_failed", mapOf("error" to (e.message ?: "").take(100)))
                                        message = context.getString(R.string.paywall_purchase_failed, e.message.orEmpty())
                                    }
                                }
                            busy = false
                        }
                    },
                    enabled = pkg != null && !busy,
                    modifier = Modifier.fillMaxWidth().height(52.dp)
                ) {
                    if (busy) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    else Text(stringResource(if (hasTrial) R.string.paywall_start_trial else R.string.paywall_subscribe))
                }
                if (hasTrial) {
                    Text(stringResource(R.string.paywall_trial_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(stringResource(R.string.paywall_renew_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    TextButton(onClick = {
                        busy = true
                        scope.launch {
                            runCatching { Purchases.sharedInstance.awaitRestore() }
                                .onSuccess { info ->
                                    PremiumManager.update(context, info)
                                    val restored = PremiumManager.isPremium.value
                                    analytics.logEvent(if (restored) "subscription_restore_success" else "subscription_restore_failed", if (restored) emptyMap() else mapOf("error" to "no_entitlement"))
                                    message = context.getString(if (restored) R.string.paywall_restored else R.string.paywall_nothing_to_restore)
                                }
                                .onFailure {
                                    analytics.logEvent("subscription_restore_failed", mapOf("error" to (it.message ?: "").take(100)))
                                    message = context.getString(R.string.paywall_nothing_to_restore)
                                }
                            busy = false
                        }
                    }, enabled = !busy) { Text(stringResource(R.string.paywall_restore)) }
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    TextButton(onClick = {
                        analytics.logEvent("privacy_policy_tap", mapOf("source" to "paywall"))
                        context.startActivity(Intent(Intent.ACTION_VIEW, PRIVACY_URL.toUri()))
                    }) { Text(stringResource(R.string.paywall_privacy)) }
                    TextButton(onClick = {
                        analytics.logEvent("terms_of_service_tap", mapOf("source" to "paywall"))
                        context.startActivity(Intent(Intent.ACTION_VIEW, TERMS_URL.toUri()))
                    }) { Text(stringResource(R.string.paywall_terms)) }
                }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun PlanCard(title: String, price: String, badge: String?, selected: Boolean, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant),
        colors = CardDefaults.cardColors(containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(price, style = MaterialTheme.typography.bodyLarge)
            badge?.let { Text(it, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge, textAlign = TextAlign.Start) }
        }
    }
}

/** 無料トライアルの日数（無ければ null） */
private fun trialDays(pkg: Package): Int? {
    val period = pkg.product.defaultOption?.freePhase?.billingPeriod ?: return null
    return when (period.unit) {
        Period.Unit.DAY -> period.value
        Period.Unit.WEEK -> period.value * 7
        Period.Unit.MONTH -> period.value * 30
        Period.Unit.YEAR -> period.value * 365
        else -> null
    }
}

/** 年額が月額×12よりどれだけ安いか（実際の価格から計算。iOS 1.4.0 と同じ考え方） */
private fun savingsPercent(monthly: Package?, annual: Package): Int? {
    val m = monthly?.product?.price?.amountMicros ?: return null
    val a = annual.product.price.amountMicros
    if (m <= 0) return null
    val percent = ((1 - a.toDouble() / (m * 12)) * 100).toInt()
    return percent.takeIf { it > 0 }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
