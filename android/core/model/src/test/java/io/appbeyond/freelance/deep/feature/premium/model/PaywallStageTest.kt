package io.appbeyond.freelance.deep.feature.premium.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * What the paywall is, and which plan it offers — `PaywallView`'s `stage`,
 * `selectedPlan` and `sharedTrialDays`, which iOS keeps inside the view.
 */
class PaywallStageTest {

  private fun plan(period: SubscriptionPlan.Period, trialDays: Int?) = SubscriptionPlan(
    id = if (period == SubscriptionPlan.Period.Yearly) DeepProduct.YEARLY else DeepProduct.MONTHLY,
    period = period,
    displayPrice = "",
    priceMicros = 1_000_000L,
    currencyCode = "USD",
    freeTrialDays = trialDays,
  )

  private val yearly = plan(SubscriptionPlan.Period.Yearly, trialDays = 7)
  private val monthly = plan(SubscriptionPlan.Period.Monthly, trialDays = 7)

  // MARK: - Stage

  @Test
  @DisplayName("The welcome beat outranks the membership the purchase just made")
  fun welcomingBeatsMember() {
    assertEquals(
      PaywallStage.Welcoming,
      PaywallStage.of(isWelcoming = true, isSubscribed = true, hasPlans = true, hasAttemptedLoad = true),
    )
  }

  @Test
  @DisplayName("A member is acknowledged, plans or not")
  fun memberBeatsPlans() {
    assertEquals(PaywallStage.Member, PaywallStage.of(false, isSubscribed = true, hasPlans = true, hasAttemptedLoad = true))
    assertEquals(PaywallStage.Member, PaywallStage.of(false, isSubscribed = true, hasPlans = false, hasAttemptedLoad = false))
  }

  @Test
  @DisplayName("Plans make it ready; none after a load is unreachable; none before one is loading")
  fun plansThenLoad() {
    assertEquals(PaywallStage.Ready, PaywallStage.of(false, false, hasPlans = true, hasAttemptedLoad = false))
    assertEquals(PaywallStage.Unreachable, PaywallStage.of(false, false, hasPlans = false, hasAttemptedLoad = true))
    assertEquals(PaywallStage.Loading, PaywallStage.of(false, false, hasPlans = false, hasAttemptedLoad = false))
  }

  // MARK: - Selection

  @Test
  @DisplayName("Untouched, the selection resolves to the yearly plan wherever it is listed")
  fun yearlyIsPreselected() {
    assertEquals(yearly, PaywallPlans.selected(listOf(monthly, yearly), selectedId = null))
  }

  @Test
  @DisplayName("A chosen plan wins; a stale choice falls back to yearly")
  fun choiceWins() {
    assertEquals(monthly, PaywallPlans.selected(listOf(yearly, monthly), selectedId = DeepProduct.MONTHLY))
    assertEquals(yearly, PaywallPlans.selected(listOf(yearly, monthly), selectedId = "deep.gone"))
  }

  @Test
  @DisplayName("Without a yearly plan the first one stands; without plans, nothing")
  fun fallbacks() {
    assertEquals(monthly, PaywallPlans.selected(listOf(monthly), selectedId = null))
    assertNull(PaywallPlans.selected(emptyList(), selectedId = null))
  }

  // MARK: - Shared trial

  @Test
  @DisplayName("A trial every plan offers is said once over the group")
  fun sharedTrial() {
    assertEquals(7, PaywallPlans.sharedTrialDays(listOf(yearly, monthly)))
  }

  @Test
  @DisplayName("Trials that differ — or only one plan's — belong to their rows")
  fun mixedTrials() {
    assertNull(PaywallPlans.sharedTrialDays(listOf(yearly, plan(SubscriptionPlan.Period.Monthly, trialDays = null))))
    assertNull(PaywallPlans.sharedTrialDays(listOf(yearly, plan(SubscriptionPlan.Period.Monthly, trialDays = 3))))
    assertNull(PaywallPlans.sharedTrialDays(emptyList()))
  }
}
