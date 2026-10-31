package io.appbeyond.freelance.deep.feature.premium.model

/**
 * What the paywall *is*, as opposed to what the member is doing on it —
 * purchasing decorates [Ready] rather than replacing it.
 *
 * Ported from `PaywallView.Stage` (Deep/Deep/Features/Premium/Screens/PaywallView.swift).
 */
enum class PaywallStage {
  /** The plans haven't come back yet: a breathing skeleton and "One moment". */
  Loading,

  /** The store answered with nothing to sell: a quiet line and "Try again". */
  Unreachable,

  /** Plans to choose from, and the act that buys one. */
  Ready,

  /** The store already sees a membership: an acknowledgement and "Done". */
  Member,

  /** The beat between a successful purchase and leaving the screen. */
  Welcoming,
  ;

  /** Stages whose content is a few lines rather than a screenful — centred rather than hung from the top. */
  val isShort: Boolean get() = this == Welcoming || this == Member

  /** Stages still offering something, so they carry the fine print and the way out. */
  val isSelling: Boolean get() = this != Member && this != Welcoming

  companion object {
    /**
     * Checked in order, and the order matters: a completed purchase flips the
     * store to subscribed, which would otherwise swap the screen to the
     * already-a-member acknowledgement instead of letting the welcome beat
     * play. Without [hasAttemptedLoad], "still loading" and "the store has
     * nothing for us" would look identical.
     */
    fun of(isWelcoming: Boolean, isSubscribed: Boolean, hasPlans: Boolean, hasAttemptedLoad: Boolean): PaywallStage =
      when {
        isWelcoming -> Welcoming
        isSubscribed -> Member
        hasPlans -> Ready
        hasAttemptedLoad -> Unreachable
        else -> Loading
      }
  }
}

/** Which plan the paywall offers, and what it may claim about all of them. */
object PaywallPlans {

  /**
   * The plan the act would buy. Yearly is the preselection without needing to
   * be written into state: an untouched selection — or one naming a plan the
   * store no longer offers — simply resolves to it.
   */
  fun selected(plans: List<SubscriptionPlan>, selectedId: String?): SubscriptionPlan? =
    plans.firstOrNull { it.id == selectedId }
      ?: plans.firstOrNull { it.period == SubscriptionPlan.Period.Yearly }
      ?: plans.firstOrNull()

  /**
   * The trial every plan offers, or null when they differ — including when
   * only one of them has one. Said once over the group only when it is true
   * of the group; otherwise each row carries its own.
   */
  fun sharedTrialDays(plans: List<SubscriptionPlan>): Int? {
    val first = plans.firstOrNull() ?: return null
    return first.freeTrialDays.takeIf { days -> plans.all { it.freeTrialDays == days } }
  }
}
