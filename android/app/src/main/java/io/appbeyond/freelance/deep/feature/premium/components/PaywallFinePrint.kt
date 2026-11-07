package io.appbeyond.freelance.deep.feature.premium.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.premium.model.PaywallPricing
import io.appbeyond.freelance.deep.feature.premium.model.PaywallPricing.BillingFacts
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlanFormatting
import io.appbeyond.freelance.deep.feature.premium.store.MockSubscriptionStore
import io.appbeyond.freelance.deep.shared.components.LegalText
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm
import java.math.BigDecimal
import java.util.Locale

private val LINE_SPACING = 10.dp
private val RESTORE_SPACING = 6.dp
private val RESTORE_TOP_PADDING = 2.dp

/** The restore control's tap target — iOS's `frame(minHeight: 44)`. */
private val RESTORE_MIN_HEIGHT = 44.dp

private val FinePrintStyle: TextStyle = UntrackedMicro.copy(textAlign = TextAlign.Center)

/**
 * Where a restore attempt has got to. Mirrors the machine Settings already
 * runs, so backing out of Google Play's prompt says nothing in either place.
 * Ported from `PaywallRestorePhase`.
 */
enum class PaywallRestorePhase {
  Idle,
  Working,

  /**
   * Google Play answered, and there was nothing on this account to bring
   * back. Worth saying: silence after tapping Restore reads as a dead button.
   */
  NothingFound,

  /**
   * Something was restored. The screen itself becomes the acknowledgement, so
   * this is carried by the member stage rather than by the fine print.
   */
  Restored,
  Failed,
}

/**
 * The foot of the paywall: what will be charged, that it renews, the two
 * legal documents, and a way back to a purchase already made.
 *
 * Ported from Deep/Deep/Features/Premium/Components/PaywallFinePrint.swift,
 * with Google Play where the App Store stood. None of this is decoration: a
 * subscription screen must state its terms and link its documents, so this
 * band ships even in the states where there is no price to name.
 *
 * @param billingLine null when there is no plan to price — the offline branch
 *   keeps the links and the restore, and simply says nothing about money.
 */
@Composable
fun PaywallFinePrint(
  billingLine: String?,
  restore: PaywallRestorePhase,
  onRestore: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier = modifier.fillMaxWidth(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(LINE_SPACING),
  ) {
    billingLine?.let { FinePrintLine(it) }
    FinePrintLine(stringResource(R.string.paywall_renews))
    Text(text = LegalText.invitation(), style = FinePrintStyle, color = Color.driftGrey)
    RestoreControl(restore, onRestore, Modifier.padding(top = RESTORE_TOP_PADDING))
  }
}

@Composable
private fun FinePrintLine(text: String) {
  Text(text = text, style = FinePrintStyle, color = Color.driftGrey, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun RestoreControl(restore: PaywallRestorePhase, onRestore: () -> Unit, modifier: Modifier = Modifier) {
  when (restore) {
    PaywallRestorePhase.Working -> Box(modifier) { FinePrintLine(stringResource(R.string.paywall_restoring)) }
    // Reached only if the restore brought back nothing that changes the
    // screen; normally the member acknowledgement takes over from here.
    PaywallRestorePhase.Restored -> Box(modifier) { FinePrintLine(stringResource(R.string.paywall_restored)) }
    PaywallRestorePhase.Idle, PaywallRestorePhase.Failed, PaywallRestorePhase.NothingFound -> Column(
      modifier = modifier,
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(RESTORE_SPACING),
    ) {
      Box(
        Modifier
          .heightIn(min = RESTORE_MIN_HEIGHT)
          .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onRestore),
        contentAlignment = Alignment.Center,
      ) {
        Text(text = stringResource(R.string.paywall_restore), style = FinePrintStyle, color = Color.deepPlum)
      }
      // Quiet lines, never an alert — the same way Settings says it.
      when (restore) {
        PaywallRestorePhase.Failed -> FinePrintLine(stringResource(R.string.paywall_restore_failed))
        PaywallRestorePhase.NothingFound -> FinePrintLine(stringResource(R.string.paywall_restore_nothing))
        else -> Unit
      }
    }
  }
}

/**
 * The money sentence under the plans — what is charged, and when — for the
 * selected plan. Every figure goes through the one money recipe
 * ([SubscriptionPlanFormatting.money]), so the sentence can't quote a
 * different cent from the row above it.
 */
@Composable
internal fun billingLine(plan: SubscriptionPlan, deviceLocale: Locale): String {
  val locale = plan.priceLocale ?: deviceLocale
  fun money(amount: BigDecimal) = SubscriptionPlanFormatting.money(amount, plan.currencyCode, locale)
  return when (val facts = PaywallPricing.billingFacts(plan)) {
    is BillingFacts.TrialThenYearly -> pluralStringResource(
      R.plurals.paywall_billing_trial_yearly,
      facts.trialDays,
      facts.trialDays,
      money(facts.perMonth),
      money(facts.total),
    )
    is BillingFacts.TrialThenMonthly -> pluralStringResource(
      R.plurals.paywall_billing_trial_monthly,
      facts.trialDays,
      facts.trialDays,
      money(facts.total),
    )
    is BillingFacts.Yearly -> stringResource(R.string.paywall_billing_yearly, money(facts.perMonth), money(facts.total))
    is BillingFacts.Monthly -> stringResource(R.string.paywall_billing_monthly, money(facts.total))
  }
}

@Preview(showBackground = true, name = "Paywall fine print")
@Composable
private fun PaywallFinePrintPreview() {
  OnboardingPreviewBackdrop {
    Column(
      Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      PaywallFinePrint(
        billingLine = billingLine(MockSubscriptionStore.samplePlans.first(), Locale.US),
        restore = PaywallRestorePhase.Idle,
        onRestore = {},
      )
      PaywallFinePrint(billingLine = null, restore = PaywallRestorePhase.Failed, onRestore = {})
      PaywallFinePrint(billingLine = null, restore = PaywallRestorePhase.NothingFound, onRestore = {})
    }
  }
}
