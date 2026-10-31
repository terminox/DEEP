package io.appbeyond.freelance.deep.feature.premium.components

import android.content.res.Resources
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.SelectionMark
import io.appbeyond.freelance.deep.feature.onboarding.components.selectionRim
import io.appbeyond.freelance.deep.feature.premium.model.PaywallPricing
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlanFormatting
import io.appbeyond.freelance.deep.feature.premium.store.MockSubscriptionStore
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.irisDusk
import io.appbeyond.freelance.deep.theme.pebble
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress
import java.util.Locale

// MARK: - Constants

/** The row's inset — iOS's `.padding(.vertical, 16).padding(.horizontal, 18)`. */
private val PADDING_VERTICAL = 16.dp
private val PADDING_HORIZONTAL = 18.dp
private val ROW_SPACING = 14.dp
private val NAME_SPACING = 3.dp
private val PRICE_SPACING = 5.dp
private val STACKED_SPACING = 8.dp

/** The savings badge's pebble — iOS's `.padding(.horizontal, 10).padding(.vertical, 4)`. */
private val BADGE_PADDING_HORIZONTAL = 10.dp
private val BADGE_PADDING_VERTICAL = 4.dp

/** The unchosen ring — iOS's `driftGrey.opacity(0.5)`. */
private const val HOLLOW_MARK_ALPHA = 0.5f

/**
 * Past this font scale a two-column row can only fight itself, so it stacks —
 * iOS's `dynamicTypeSize.isAccessibilitySize`, which begins at about 1.5× the
 * default size.
 */
private const val STACKED_FONT_SCALE = 1.5f

/**
 * The micro size without its all-caps tracking — iOS's `DeepType.micro`,
 * which tracks only where `.tracking(.microTracking)` asks for it. A sentence
 * or a badge tracked like an eyebrow reads as letter-spaced.
 */
internal val UntrackedMicro = DeepType.micro.copy(letterSpacing = TextUnit.Unspecified)

// MARK: - Row

/**
 * One selectable plan: its name and what it costs, with what a year saves
 * said plainly beside it.
 *
 * Ported from Deep/Deep/Features/Premium/Components/PaywallPlanRow.swift. It
 * wears the quiz option card's selection grammar — the same frosted card, the
 * same lavender rim, the same check ([QuizOptionCard][io.appbeyond.freelance.deep.feature.onboarding.components.QuizOptionCard]'s
 * [SelectionMark] and [selectionRim]) — but moves the mark to the leading
 * edge, because the trailing edge here belongs to the price. Nothing new is
 * invented; the pieces just stand in a different order. At very large type
 * it stacks into one column, always, rather than deciding afresh per launch.
 *
 * @param savingsPercent what this plan saves against the other, in whole
 *   percent — null on the baseline plan, and whenever there is nothing
 *   honest to claim.
 * @param showsTrialNote whether this row carries its own trial; the screen
 *   states a shared trial once above the group instead.
 * @param deviceLocale how the device spells money when the plan doesn't say —
 *   the locale Play formatted [SubscriptionPlan.displayPrice] in.
 */
@Composable
fun PaywallPlanRow(
  plan: SubscriptionPlan,
  isSelected: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  savingsPercent: Int? = null,
  showsTrialNote: Boolean = false,
  deviceLocale: Locale = rememberDeviceLocale(),
) {
  val shape = RoundedCornerShape(Dp.card)
  val rimAlpha by animateFloatAsState(
    targetValue = if (isSelected) 1f else 0f,
    animationSpec = settle(),
    label = "paywall-plan-rim",
  )
  val stacked = LocalDensity.current.fontScale >= STACKED_FONT_SCALE
  val subline = planSubline(plan, deviceLocale)
  val trialNote = plan.freeTrialDays?.takeIf { showsTrialNote }?.let { days ->
    pluralStringResource(R.plurals.paywall_trial_note, days, days)
  }
  val savings = savingsPercent?.let { percent ->
    stringResource(R.string.paywall_save, AppFormat.percent(percent / PERCENT, rememberAppLocale()))
  }

  Row(
    modifier = modifier
      .fillMaxWidth()
      .frostedCard(cornerRadius = Dp.card)
      .selectionRim(rimAlpha, shape)
      .softPress()
      .selectable(
        selected = isSelected,
        role = Role.RadioButton,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      .padding(vertical = PADDING_VERTICAL, horizontal = PADDING_HORIZONTAL),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = if (stacked) Alignment.Top else Alignment.CenterVertically,
  ) {
    SelectionMark(isSelected = isSelected, hollowAlpha = HOLLOW_MARK_ALPHA)

    if (stacked) {
      Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(STACKED_SPACING)) {
        PlanName(plan)
        trialNote?.let { TrialNote(it) }
        PriceColumn(plan.displayPrice, subline, savings, Alignment.Start)
      }
    } else {
      // A weighted column rather than a Spacer: a Spacer bids against the text
      // and wraps the plan's name on a row with room to spare.
      Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(NAME_SPACING)) {
        PlanName(plan)
        Subline(subline)
        trialNote?.let { TrialNote(it) }
      }
      PriceColumn(plan.displayPrice, subline = null, savings, Alignment.End)
    }
  }
}

@Composable
private fun PlanName(plan: SubscriptionPlan) {
  Text(
    text = stringResource(
      if (plan.period == SubscriptionPlan.Period.Yearly) R.string.paywall_plan_yearly else R.string.paywall_plan_monthly,
    ),
    style = DeepType.body,
    color = Color.deepPlum,
  )
}

@Composable
private fun Subline(text: String) {
  Text(text = text, style = DeepType.caption, color = Color.driftGrey)
}

@Composable
private fun TrialNote(text: String) {
  Text(text = text, style = UntrackedMicro, color = Color.irisDusk)
}

/** The price, the subline when stacked, and the savings badge in its pebble — the inset tonal panel, not a new style. */
@Composable
private fun PriceColumn(price: String, subline: String?, savings: String?, alignment: Alignment.Horizontal) {
  Column(horizontalAlignment = alignment, verticalArrangement = Arrangement.spacedBy(PRICE_SPACING)) {
    Text(
      text = price,
      style = DeepType.body.copy(fontWeight = FontWeight.SemiBold),
      color = Color.deepPlum,
      textAlign = if (alignment == Alignment.End) TextAlign.End else TextAlign.Start,
    )
    subline?.let { Subline(it) }
    savings?.let {
      Text(
        text = it,
        style = UntrackedMicro,
        color = Color.irisDusk,
        modifier = Modifier
          .pebble(cornerRadius = Dp.chip)
          .padding(horizontal = BADGE_PADDING_HORIZONTAL, vertical = BADGE_PADDING_VERTICAL),
      )
    }
  }
}

/**
 * The label under a plan's name: what a year works out to per month, or the
 * plain billing period for a plan that is already monthly — its per-month
 * figure is its price, which sits alongside already.
 */
@Composable
private fun planSubline(plan: SubscriptionPlan, deviceLocale: Locale): String = when (plan.period) {
  SubscriptionPlan.Period.Monthly -> stringResource(R.string.paywall_billed_monthly)
  SubscriptionPlan.Period.Yearly ->
    stringResource(R.string.paywall_per_month, SubscriptionPlanFormatting.perMonthPrice(plan, deviceLocale))
}

/**
 * The device's own locale — not the language DEEP reads in. Play formats a
 * plan's `displayPrice` in the device's locale, so a derived figure spelled
 * any other way would sit beside it looking like a different currency
 * ("US$7.67" under "$91.98").
 */
@Composable
@ReadOnlyComposable
internal fun rememberDeviceLocale(): Locale =
  Resources.getSystem().configuration.locales.get(0) ?: Locale.ROOT

private const val PERCENT = 100f

// MARK: - Previews

@Preview(showBackground = true, name = "Paywall plan row")
@Composable
private fun PaywallPlanRowPreview() {
  var selected by remember { mutableStateOf(MockSubscriptionStore.samplePlans.first().id) }
  val plans = MockSubscriptionStore.samplePlans
  OnboardingPreviewBackdrop {
    Column(
      Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
    ) {
      plans.forEach { plan ->
        PaywallPlanRow(
          plan = plan,
          isSelected = selected == plan.id,
          onClick = { selected = plan.id },
          savingsPercent = if (plan.period == SubscriptionPlan.Period.Yearly) PaywallPricing.yearlySavingsPercent(plans) else null,
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Paywall plan row — mixed trials, large type", fontScale = 1.6f)
@Composable
private fun PaywallPlanRowLargeTypePreview() {
  val plans = MockSubscriptionStore.mixedTrialPlans
  OnboardingPreviewBackdrop {
    Column(
      Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
    ) {
      plans.forEach { plan ->
        PaywallPlanRow(
          plan = plan,
          isSelected = plan.period == SubscriptionPlan.Period.Yearly,
          onClick = {},
          savingsPercent = if (plan.period == SubscriptionPlan.Period.Yearly) PaywallPricing.yearlySavingsPercent(plans) else null,
          showsTrialNote = true,
        )
      }
    }
  }
}
