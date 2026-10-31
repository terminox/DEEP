package io.appbeyond.freelance.deep.feature.premium

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.CraftingChecklistRow
import io.appbeyond.freelance.deep.feature.onboarding.components.DeepLogoMark
import io.appbeyond.freelance.deep.feature.onboarding.screens.OnboardingLogoText
import io.appbeyond.freelance.deep.feature.premium.components.PaywallFinePrint
import io.appbeyond.freelance.deep.feature.premium.components.PaywallPlanRow
import io.appbeyond.freelance.deep.feature.premium.components.PaywallRestorePhase
import io.appbeyond.freelance.deep.feature.premium.components.billingLine
import io.appbeyond.freelance.deep.feature.premium.components.rememberDeviceLocale
import io.appbeyond.freelance.deep.feature.premium.model.DeepProduct
import io.appbeyond.freelance.deep.feature.premium.model.PaywallPlans
import io.appbeyond.freelance.deep.feature.premium.model.PaywallPricing
import io.appbeyond.freelance.deep.feature.premium.model.PaywallSource
import io.appbeyond.freelance.deep.feature.premium.model.PaywallStage
import io.appbeyond.freelance.deep.feature.premium.model.PurchaseOutcome
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import io.appbeyond.freelance.deep.feature.premium.store.FakePremiumAccess
import io.appbeyond.freelance.deep.feature.premium.store.MockSubscriptionStore
import io.appbeyond.freelance.deep.feature.premium.store.SubscriptionStore
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.RewardContinueButton
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.NOTE_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.WELCOME_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// MARK: - Constants

/** The mark a size down from the account screen's, and a little larger while welcoming — iOS's 56 / 72. */
private val MARK_SIZE = 56.dp
private val MARK_SIZE_WELCOMING = 72.dp
private val MARK_TOP_PADDING = 4.dp

/** The wordmark's width — iOS's `frame(maxWidth: 170)`. */
private val LOGO_TEXT_MAX_WIDTH = 170.dp

private val HERO_SPACING = 14.dp
private val CONTENT_BOTTOM_PADDING = 12.dp

/** The benefits card — iOS's `VStack(spacing: 18)`, `.padding(.vertical, 20).padding(.horizontal, 18)`. */
private val BENEFIT_SPACING = 18.dp
private val BENEFIT_PADDING_VERTICAL = 20.dp
private val BENEFIT_PADDING_HORIZONTAL = 18.dp

private val PLAN_SPACING = 14.dp

/** The skeleton mirrors the real rows' geometry, so nothing jumps when the plans land. */
private val SKELETON_LABEL_WIDTH = 96.dp
private val SKELETON_ROW_HEIGHT = 84.dp
private const val SKELETON_ROWS = 2

/** The unreachable note — iOS's chip (`.padding(.horizontal, 22).padding(.vertical, 12)`) and its air. */
private val UNREACHABLE_SPACING = 14.dp
private val UNREACHABLE_PADDING_VERTICAL = 24.dp
private val RETRY_PADDING_HORIZONTAL = 22.dp
private val RETRY_PADDING_VERTICAL = 12.dp

/** The action bar — iOS's `VStack(spacing: 12)`, `.padding(.top, 14).padding(.bottom, 12)`. */
private val BAR_SPACING = 12.dp
private val BAR_PADDING_TOP = 14.dp
private val BAR_PADDING_BOTTOM = 12.dp

/** The act's floor — the capsule's own 56dp, held by the labels that stand in for it. */
private val ACTION_MIN_HEIGHT = 56.dp

/** "Not right now"'s tap target — iOS's `frame(minHeight: 44)`. */
private val DECLINE_MIN_HEIGHT = 44.dp

// MARK: - State

/**
 * Where a purchase has got to — iOS's `PaywallView.PurchasePhase`.
 * [Welcoming] is the beat between a successful purchase and leaving the screen.
 */
sealed interface PurchasePhase {
  data object Idle : PurchasePhase
  data class Purchasing(val productId: String) : PurchasePhase
  data object Pending : PurchasePhase
  data object Failed : PurchasePhase
  data object Welcoming : PurchasePhase
}

// MARK: - Screen

/**
 * The one paywall. Every door opens onto this screen; only the subhead knows
 * which door it was ([source]).
 *
 * Ported from Deep/Deep/Features/Premium/Screens/PaywallView.swift. It is a
 * screen, not a sheet or a dialog — a place you go: pushed onto a tab's stack
 * from Settings or a locked sound, onto the plant picker's own stack inside
 * its sheet, and stood up as a step in the first run. One arrangement serves
 * every door, so nothing about it branches on how it was reached.
 *
 * There is no close control in a corner, deliberately. An X reads as an
 * escape hatch from a demand, and this is meant to read as an invitation: the
 * way out is a quiet "Not right now" at the foot — and system back, wherever
 * the screen's coordinator allows it.
 *
 * It reads the purchasing store and the one premium answer from
 * [LocalSubscriptionStore] / [LocalPremiumAccess], and the store's sheet needs
 * this screen's activity ([LocalActivity]). Stages, in order: welcoming →
 * member → ready → unreachable → loading ([PaywallStage.of]). A purchase
 * unlocks at once on the store's word ([PremiumAccess.didPurchase][io.appbeyond.freelance.deep.feature.premium.store.PremiumAccess.didPurchase]),
 * holds the welcome for [WELCOME_HOLD_MILLIS] with a success haptic, then
 * finishes; backing out of Play's sheet says nothing; a payment awaiting
 * approval and a failure each leave a quiet line under the act.
 *
 * Only the act is pinned. The fine print scrolls with the content it
 * describes — pinning it too would leave the plan rows a sliver of screen,
 * with the monthly option hidden behind a wall of terms. The pinned bar sits
 * above [LocalMiniPlayerClearance], so a playing track's pill never covers it.
 *
 * @param onFinish the member is done here — bought, declined or acknowledged.
 *   The screen never leaves under its own power: the coordinator that pushed
 *   it pops it, or routes on.
 * @param drawsAtmosphere false where a coordinator already keeps one
 *   persistent atmosphere under every step (onboarding), so a hand-off never
 *   crossfades two of them.
 * @param initialPurchase opens the screen already in a state a tap would
 *   otherwise have to produce — previews only.
 */
@Composable
fun PaywallScreen(
  source: PaywallSource,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  drawsAtmosphere: Boolean = true,
  initialPurchase: PurchasePhase = PurchasePhase.Idle,
) {
  val store = LocalSubscriptionStore.current
  val premiumAccess = LocalPremiumAccess.current
  val activity = LocalActivity.current
  val haptics = LocalHapticFeedback.current
  val scope = rememberCoroutineScope()
  val deviceLocale = rememberDeviceLocale()

  val status by store.status.collectAsStateWithLifecycle()
  val plans by store.plans.collectAsStateWithLifecycle()

  var selectedPlanId by rememberSaveable { mutableStateOf<String?>(null) }
  var purchase by remember { mutableStateOf(initialPurchase) }
  var restore by remember { mutableStateOf(PaywallRestorePhase.Idle) }
  // Whether `loadPlans()` has returned at least once. Without it, "still
  // loading" and "the store has nothing for us" look identical.
  var hasAttemptedLoad by remember { mutableStateOf(false) }
  var loadAttempt by remember { mutableIntStateOf(0) }

  LaunchedEffect(store, loadAttempt) {
    hasAttemptedLoad = false
    try {
      store.loadPlans()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      // An unreachable store reads as no plans, whatever the reason.
    }
    hasAttemptedLoad = true
  }

  val stage = PaywallStage.of(
    isWelcoming = purchase == PurchasePhase.Welcoming,
    isSubscribed = status.isSubscribed,
    hasPlans = plans.isNotEmpty(),
    hasAttemptedLoad = hasAttemptedLoad,
  )
  val selectedPlan = PaywallPlans.selected(plans, selectedPlanId)
  val isPurchasing = purchase is PurchasePhase.Purchasing

  // The welcome beat, felt as well as read.
  LaunchedEffect(stage == PaywallStage.Welcoming) {
    if (stage == PaywallStage.Welcoming) haptics.performHapticFeedback(HapticFeedbackType.Confirm)
  }

  fun buy() {
    val plan = selectedPlan ?: return
    val host = activity ?: return
    if (isPurchasing) return
    purchase = PurchasePhase.Purchasing(plan.id)
    scope.launch {
      try {
        when (store.purchase(host, plan)) {
          PurchaseOutcome.Purchased -> {
            // Unlock now, on the store's word, and have the server confirm it
            // behind the welcome — content re-fetches when it does.
            premiumAccess.didPurchase()
            purchase = PurchasePhase.Welcoming
            // A beat to read the welcome, then out. No confetti.
            delay(WELCOME_HOLD_MILLIS)
            onFinish()
          }
          // Backing out is not a failure. Say nothing at all.
          PurchaseOutcome.Cancelled -> purchase = PurchasePhase.Idle
          PurchaseOutcome.Pending -> purchase = PurchasePhase.Pending
        }
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        purchase = PurchasePhase.Failed
        delay(NOTE_HOLD_MILLIS)
        if (purchase == PurchasePhase.Failed) purchase = PurchasePhase.Idle
      }
    }
  }

  // The restore machine Settings already runs: a failure is a quiet line, and
  // either way the control settles back after a beat.
  fun restorePurchases() {
    if (restore == PaywallRestorePhase.Working) return
    restore = PaywallRestorePhase.Working
    scope.launch {
      try {
        store.restore()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        restore = PaywallRestorePhase.Failed
        delay(NOTE_HOLD_MILLIS)
        if (restore == PaywallRestorePhase.Failed) restore = PaywallRestorePhase.Idle
        return@launch
      }
      // A restore that lands turns the screen into the member
      // acknowledgement, which is the confirmation. One that finds nothing has
      // to say so — a Restore that answers with silence reads as a dead button.
      val found = store.status.value.isSubscribed
      restore = if (found) PaywallRestorePhase.Restored else PaywallRestorePhase.NothingFound
      // The server has to hear about it too, or the audio it withholds stays
      // withheld: confirm a restored membership the way a purchase is.
      if (found) premiumAccess.didPurchase()
      delay(NOTE_HOLD_MILLIS)
      if (restore == PaywallRestorePhase.Restored || restore == PaywallRestorePhase.NothingFound) {
        restore = PaywallRestorePhase.Idle
      }
    }
  }

  Box(
    modifier
      .fillMaxSize()
      .then(if (drawsAtmosphere) Modifier.background(Color.moonCream) else Modifier),
  ) {
    // The screen owns its own ground, so it reads the same wherever it is pushed.
    if (drawsAtmosphere) AtmosphereBackground()

    Column(Modifier.fillMaxSize()) {
      BoxWithConstraints(
        Modifier
          .weight(1f)
          .fillMaxWidth()
          .statusBarsPadding(),
      ) {
        val viewport = maxHeight
        Column(
          Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        ) {
          Column(
            Modifier
              .fillMaxWidth()
              // The welcome beat and the member acknowledgement are a few
              // lines each; hung from the top of a full-height screen they sit
              // above a void. Centred only then, since a scrolling screen
              // pinned to the viewport would clip everything past the fold.
              .heightIn(min = if (stage.isShort) viewport else 0.dp)
              .padding(horizontal = Dp.edge)
              .padding(top = Dp.rhythm, bottom = CONTENT_BOTTOM_PADDING),
            verticalArrangement = Arrangement.spacedBy(
              Dp.rhythm,
              if (stage.isShort) Alignment.CenterVertically else Alignment.Top,
            ),
          ) {
            Hero(stage = stage, source = source, status = status, restore = restore)
            AnimatedVisibility(visible = stage != PaywallStage.Member, enter = fadeIn(bloom()), exit = fadeOut(bloom())) {
              Benefits()
            }
            PlanBand(
              stage = stage,
              plans = plans,
              selectedPlan = selectedPlan,
              isPurchasing = isPurchasing,
              onSelect = { plan ->
                if (plan.id != selectedPlan?.id) haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                selectedPlanId = plan.id
              },
              onRetry = { loadAttempt += 1 },
            )
            if (stage.isSelling) {
              PaywallFinePrint(
                billingLine = selectedPlan?.takeIf { stage == PaywallStage.Ready }?.let { billingLine(it, deviceLocale) },
                restore = restore,
                onRestore = ::restorePurchases,
              )
            }
          }
        }
      }

      ActionBar(
        stage = stage,
        purchase = purchase,
        trialDays = selectedPlan?.freeTrialDays,
        onBuy = ::buy,
        onFinish = onFinish,
      )
    }
  }
}

// MARK: - Hero

/**
 * The same lockup the account screen wears, a size down: arriving here
 * straight from signing up, it should read as the same doorway. The product's
 * name on every door; only the two stages no longer selling say otherwise.
 */
@Composable
private fun Hero(stage: PaywallStage, source: PaywallSource, status: SubscriptionState, restore: PaywallRestorePhase) {
  // The mark is drawn once at its welcoming size and scaled down from it:
  // its halo is a blurred mask cached per size, so animating the size itself
  // would re-blur it every frame of the bloom.
  val markScale by animateFloatAsState(
    targetValue = if (stage == PaywallStage.Welcoming) 1f else MARK_SIZE / MARK_SIZE_WELCOMING,
    animationSpec = bloom(),
    label = "paywall-mark",
  )
  val headline = stringResource(
    when (stage) {
      PaywallStage.Welcoming -> R.string.paywall_headline_welcome
      PaywallStage.Member -> R.string.paywall_headline_member
      else -> R.string.paywall_headline
    },
  )
  val subhead = stringResource(
    when (stage) {
      PaywallStage.Welcoming -> R.string.paywall_subhead_welcome
      PaywallStage.Member -> memberSubhead(status, restore)
      else -> source.subhead
    },
  )

  Column(
    Modifier.fillMaxWidth(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(HERO_SPACING),
  ) {
    Box(
      Modifier
        .padding(top = MARK_TOP_PADDING)
        .size(MARK_SIZE_WELCOMING * markScale),
      contentAlignment = Alignment.Center,
    ) {
      DeepLogoMark(
        size = MARK_SIZE_WELCOMING,
        tint = Color.moonCream,
        isGlowing = true,
        modifier = Modifier
          .requiredSize(MARK_SIZE_WELCOMING)
          .graphicsLayer {
            scaleX = markScale
            scaleY = markScale
          },
      )
    }
    OnboardingLogoText(Modifier.widthIn(max = LOGO_TEXT_MAX_WIDTH))
    Crossfade(targetState = headline, animationSpec = bloom(), label = "paywall-headline") { text ->
      Text(
        text = text,
        style = DeepType.displayTitle,
        color = Color.deepPlum,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().semantics { heading() },
      )
    }
    Crossfade(targetState = subhead, animationSpec = bloom(), label = "paywall-subhead") { text ->
      Text(
        text = text,
        style = DeepType.caption,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
      )
    }
  }
}

/** The door's own line — iOS's `PaywallSource.subhead`. */
private val PaywallSource.subhead: Int
  get() = when (this) {
    PaywallSource.Settings -> R.string.paywall_subhead_settings
    PaywallSource.LockedSound -> R.string.paywall_subhead_locked_sound
    PaywallSource.LockedPlant -> R.string.paywall_subhead_locked_plant
    PaywallSource.Onboarding -> R.string.paywall_subhead_onboarding
  }

/**
 * A restore that just landed here is what the member was waiting to be told;
 * the plan line takes over once the acknowledgement has been read. The plan
 * is read off the product id, in either shape (Play's `subscription:basePlan`).
 */
private fun memberSubhead(status: SubscriptionState, restore: PaywallRestorePhase): Int {
  if (restore == PaywallRestorePhase.Restored) return R.string.paywall_restored
  val productId = (status as? SubscriptionState.Subscribed)?.productId ?: return R.string.paywall_member
  return when (DeepProduct.planOf(productId)) {
    SubscriptionPlan.Period.Yearly -> R.string.paywall_member_yearly
    SubscriptionPlan.Period.Monthly -> R.string.paywall_member_monthly
    null -> R.string.paywall_member
  }
}

// MARK: - Benefits

/**
 * Constant across every door — what the membership includes doesn't depend on
 * where you were standing when you asked. Two lines, because two is what the
 * app actually unlocks today; a third would have to be invented.
 */
@Composable
private fun Benefits() {
  Column(
    Modifier
      .fillMaxWidth()
      .frostedCard(cornerRadius = Dp.card)
      .padding(vertical = BENEFIT_PADDING_VERTICAL, horizontal = BENEFIT_PADDING_HORIZONTAL),
    verticalArrangement = Arrangement.spacedBy(BENEFIT_SPACING),
  ) {
    CraftingChecklistRow(title = stringResource(R.string.paywall_benefit_sounds), isDone = true)
    CraftingChecklistRow(title = stringResource(R.string.paywall_benefit_plants), isDone = true)
  }
}

// MARK: - Plans

@Composable
private fun PlanBand(
  stage: PaywallStage,
  plans: List<SubscriptionPlan>,
  selectedPlan: SubscriptionPlan?,
  isPurchasing: Boolean,
  onSelect: (SubscriptionPlan) -> Unit,
  onRetry: () -> Unit,
) {
  AnimatedContent(
    targetState = stage,
    transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
    contentKey = { it },
    label = "paywall-plan-band",
  ) { current ->
    when (current) {
      PaywallStage.Loading -> PlanSkeleton()
      PaywallStage.Unreachable -> UnreachableNote(onRetry)
      PaywallStage.Ready -> PlanList(plans, selectedPlan, isPurchasing, onSelect)
      PaywallStage.Member, PaywallStage.Welcoming -> Box(Modifier.fillMaxWidth())
    }
  }
}

@Composable
private fun PlanList(
  plans: List<SubscriptionPlan>,
  selectedPlan: SubscriptionPlan?,
  isPurchasing: Boolean,
  onSelect: (SubscriptionPlan) -> Unit,
) {
  val sharedTrialDays = PaywallPlans.sharedTrialDays(plans)
  val savings = PaywallPricing.yearlySavingsPercent(plans)

  Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(PLAN_SPACING)) {
    if (sharedTrialDays != null) {
      // Said once over the group, but only when it is true of the group.
      Text(
        text = pluralStringResource(R.plurals.paywall_days_free, sharedTrialDays, sharedTrialDays),
        style = DeepType.micro,
        color = Color.driftGrey,
      )
    }
    plans.forEach { plan ->
      PaywallPlanRow(
        plan = plan,
        isSelected = selectedPlan?.id == plan.id,
        // A choice is held still while a purchase is on its way.
        onClick = { if (!isPurchasing) onSelect(plan) },
        savingsPercent = if (plan.period == SubscriptionPlan.Period.Yearly) savings else null,
        // When the plans don't offer the same trial, the claim belongs to the
        // row that owns it — a banner over a plan with no trial is an offer
        // the store will not honour.
        showsTrialNote = sharedTrialDays == null,
      )
    }
  }
}

@Composable
private fun PlanSkeleton() {
  Column(
    Modifier.fillMaxWidth().skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(PLAN_SPACING),
  ) {
    SkeletonTextLine(width = SKELETON_LABEL_WIDTH)
    repeat(SKELETON_ROWS) {
      SkeletonBlock(Modifier.fillMaxWidth().height(SKELETON_ROW_HEIGHT), cornerRadius = Dp.card)
    }
  }
}

/** Google Play answered with nothing — a quiet line over DEEP's frosted retry chip. */
@Composable
private fun UnreachableNote(onRetry: () -> Unit) {
  Column(
    Modifier
      .fillMaxWidth()
      .padding(vertical = UNREACHABLE_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(UNREACHABLE_SPACING),
  ) {
    Text(
      text = stringResource(R.string.paywall_unreachable),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Box(
      Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onRetry)
        .padding(horizontal = RETRY_PADDING_HORIZONTAL, vertical = RETRY_PADDING_VERTICAL),
    ) {
      Text(stringResource(R.string.paywall_try_again), style = DeepType.bodyMedium, color = Color.deepPlum)
    }
  }
}

// MARK: - Action bar

@Composable
private fun ActionBar(
  stage: PaywallStage,
  purchase: PurchasePhase,
  trialDays: Int?,
  onBuy: () -> Unit,
  onFinish: () -> Unit,
) {
  // Held through the note's fade-out, so the words don't vanish before it does.
  val noteRes = when (purchase) {
    PurchasePhase.Failed -> R.string.paywall_purchase_failed
    PurchasePhase.Pending -> R.string.paywall_purchase_pending
    else -> null
  }
  var shownNote by remember { mutableStateOf(noteRes) }
  if (noteRes != null) shownNote = noteRes

  Column(
    Modifier
      .fillMaxWidth()
      .navigationBarsPadding()
      .padding(horizontal = Dp.edge)
      .padding(top = BAR_PADDING_TOP, bottom = BAR_PADDING_BOTTOM + LocalMiniPlayerClearance.current),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(BAR_SPACING),
  ) {
    PrimaryAction(stage, purchase, trialDays, onBuy, onFinish)

    AnimatedVisibility(
      visible = noteRes != null,
      enter = fadeIn(exhale()),
      exit = fadeOut(exhale()),
      label = "paywall-note",
    ) {
      shownNote?.let {
        Text(
          text = stringResource(it),
          style = DeepType.caption,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }
    }

    if (stage.isSelling) {
      Box(
        Modifier
          .heightIn(min = DECLINE_MIN_HEIGHT)
          .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onFinish),
        contentAlignment = Alignment.Center,
      ) {
        Text(stringResource(R.string.paywall_not_now), style = DeepType.caption, color = Color.driftGrey)
      }
    }
  }
}

@Composable
private fun PrimaryAction(
  stage: PaywallStage,
  purchase: PurchasePhase,
  trialDays: Int?,
  onBuy: () -> Unit,
  onFinish: () -> Unit,
) {
  when (stage) {
    // Not a dimmed button: a disabled CTA reads as something broken. A quiet
    // label holds the same ground until there is something to buy.
    PaywallStage.Loading -> QuietLabel(stringResource(R.string.paywall_one_moment), Color.driftGrey, DeepType.body)
    PaywallStage.Unreachable -> Unit
    // The title is decided by the plans — a trial to start or not — never
    // swapped by what the member is doing; busy shows on the button itself.
    PaywallStage.Ready -> RewardContinueButton(
      title = if (trialDays == null) {
        stringResource(R.string.paywall_subscribe)
      } else {
        pluralStringResource(R.plurals.paywall_start_trial, trialDays, trialDays)
      },
      onClick = onBuy,
      isBusy = purchase is PurchasePhase.Purchasing,
      hint = stringResource(
        if (trialDays == null) R.string.paywall_subscribe_hint else R.string.paywall_start_trial_hint,
      ),
    )
    PaywallStage.Welcoming -> QuietLabel(stringResource(R.string.paywall_everything_open), Color.deepPlum, DeepType.bodyMedium)
    PaywallStage.Member -> Box(
      Modifier
        .fillMaxWidth()
        .heightIn(min = ACTION_MIN_HEIGHT)
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onFinish),
      contentAlignment = Alignment.Center,
    ) {
      Text(stringResource(R.string.paywall_done), style = DeepType.bodyMedium, color = Color.deepPlum)
    }
  }
}

@Composable
private fun QuietLabel(text: String, color: Color, style: TextStyle) {
  Box(Modifier.fillMaxWidth().heightIn(min = ACTION_MIN_HEIGHT), contentAlignment = Alignment.Center) {
    Text(text = text, style = style, color = color, textAlign = TextAlign.Center)
  }
}

// MARK: - Previews

@Composable
private fun PaywallPreview(
  store: SubscriptionStore,
  source: PaywallSource = PaywallSource.Settings,
  purchase: PurchasePhase = PurchasePhase.Idle,
) {
  DeepTheme {
    CompositionLocalProvider(
      LocalSubscriptionStore provides store,
      LocalPremiumAccess provides remember { FakePremiumAccess(hasPremium = false) },
    ) {
      PaywallScreen(source = source, onFinish = {}, initialPurchase = purchase)
    }
  }
}

@Preview(showBackground = true, name = "Paywall — plans loaded")
@Composable
private fun PaywallPlansPreview() = PaywallPreview(remember { MockSubscriptionStore.free })

@Preview(showBackground = true, name = "Paywall — only the year has a trial")
@Composable
private fun PaywallMixedTrialsPreview() = PaywallPreview(remember { MockSubscriptionStore.mixedTrials })

@Preview(showBackground = true, name = "Paywall — loading plans")
@Composable
private fun PaywallLoadingPreview() = PaywallPreview(remember { MockSubscriptionStore.loadingPlans })

@Preview(showBackground = true, name = "Paywall — store unreachable")
@Composable
private fun PaywallUnreachablePreview() = PaywallPreview(remember { MockSubscriptionStore.unreachable })

@Preview(showBackground = true, name = "Paywall — purchasing")
@Composable
private fun PaywallPurchasingPreview() =
  PaywallPreview(remember { MockSubscriptionStore.free }, purchase = PurchasePhase.Purchasing(DeepProduct.YEARLY))

@Preview(showBackground = true, name = "Paywall — purchase failed")
@Composable
private fun PaywallFailedPreview() = PaywallPreview(remember { MockSubscriptionStore.free }, purchase = PurchasePhase.Failed)

@Preview(showBackground = true, name = "Paywall — welcome beat")
@Composable
private fun PaywallWelcomePreview() = PaywallPreview(remember { MockSubscriptionStore.free }, purchase = PurchasePhase.Welcoming)

@Preview(showBackground = true, name = "Paywall — already a member")
@Composable
private fun PaywallMemberPreview() = PaywallPreview(remember { MockSubscriptionStore.subscribed })

@Preview(showBackground = true, name = "Paywall — onboarding step")
@Composable
private fun PaywallOnboardingPreview() =
  PaywallPreview(remember { MockSubscriptionStore.free }, source = PaywallSource.Onboarding)

@Preview(showBackground = true, name = "Paywall — from a locked sound")
@Composable
private fun PaywallLockedSoundPreview() =
  PaywallPreview(remember { MockSubscriptionStore.free }, source = PaywallSource.LockedSound)

@Preview(showBackground = true, name = "Paywall — large type", fontScale = 1.6f)
@Composable
private fun PaywallLargeTypePreview() = PaywallPreview(remember { MockSubscriptionStore.free })

@Preview(showBackground = true, name = "Paywall — Thai", locale = "th")
@Composable
private fun PaywallThaiPreview() = PaywallPreview(remember { MockSubscriptionStore.free })
