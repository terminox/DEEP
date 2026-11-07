package io.appbeyond.freelance.deep.feature.compassion

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.components.CompassionMotif
import io.appbeyond.freelance.deep.feature.compassion.components.GivingThanks
import io.appbeyond.freelance.deep.feature.compassion.components.HeartCapsule
import io.appbeyond.freelance.deep.feature.compassion.components.RisingHearts
import io.appbeyond.freelance.deep.feature.compassion.components.RollbackCaption
import io.appbeyond.freelance.deep.feature.compassion.model.RisingHeartsField
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.pebble
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.ZoneId

// MARK: - Constants

/** The opening suggestion — iOS's `min(10, balance)`. */
private const val OPENING_AMOUNT = 10

/**
 * How long the form steps back before the thanks blooms in, so the two never
 * cross — iOS's 0.35s.
 */
private const val THANKS_HOLD_MILLIS = 350L

/** The form receding behind the thanks — iOS's 0.96 (no scale under reduced motion). */
private const val FORM_RECEDE_SCALE = 0.96f

/** The thanks blooming in from — iOS's `.scale(scale: 0.92)` transition. */
private const val THANKS_BLOOM_FROM = 0.92f

/** Where the hearts lift off: the action's top centre, this far in — iOS's `minY + 8`. */
private val LIFT_OFF_INSET = 8.dp

/** The pad's keys — iOS's 52pt pebbles, 10pt apart. */
private val KEY_HEIGHT = 52.dp
private val KEY_SPACING = 10.dp

/** The warmth under the numeral — iOS's blush 0.32 radial, 196 × 120, radius 96. */
private const val READOUT_WARMTH_ALPHA = 0.32f
private val READOUT_WARMTH_RADIUS = 96.dp

/** An unselected quick amount — iOS's `white.opacity(0.38)` capsule. */
private const val CHIP_FILL_ALPHA = 0.38f

private const val HANDLE_ALPHA = 0.5f

private val DIGITS = listOf(listOf(1, 2, 3), listOf(4, 5, 6), listOf(7, 8, 9))

// MARK: - Sheet

/**
 * Choosing how many hearts to send to one cause. Opened from a cause card's
 * donate capsule; the coordinator owns the presentation, this owns the act.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/DonateHeartsView.swift.
 * The amount is entered on the app's own soft keypad rather than the system
 * number pad, with quick amounts above it so the common answers need no
 * typing. A Material3 [ModalBottomSheet] in DEEP's tokens, standing on the
 * atmosphere as iOS's `presentationBackground` does — the plant picker's frame.
 *
 * Giving is the moment the sheet exists for, so it is given room: hearts rise
 * from the button in proportion to the gift ([RisingHearts]), the form fades
 * back, and the sheet blooms into the app's thank-you ([GivingThanks]), which
 * the member closes themselves. If the server refuses the spend, the thanks
 * gives way to the form again and its rollback caption.
 *
 * One deliberate change from iOS: its action relabels itself per amount
 * ("Send 10 hearts", "Pick an amount") and becomes a frosted note at an empty
 * balance. DEEP's action buttons keep one title for the life of a screen, so
 * here it is always "Send hearts" — dimmed while there is nothing to commit —
 * and the readout above it carries the amount.
 *
 * @param give sends the hearts. Run on a scope that outlives the sheet, so a
 *   gift is never cut off by the sheet's own exit.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DonateHeartsSheet(
  cause: CompassionCause,
  ledger: HeartLedger,
  give: (amount: Int, causeId: String) -> Unit,
  onDismiss: () -> Unit,
) {
  val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
  val scope = rememberCoroutineScope()
  ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = sheetState,
    shape = RoundedCornerShape(topStart = Dp.card, topEnd = Dp.card),
    containerColor = Color.moonCream,
    contentColor = Color.deepPlum,
    tonalElevation = 0.dp,
    dragHandle = null,
  ) {
    DonateHeartsBody(
      cause = cause,
      ledger = ledger,
      give = give,
      onDone = {
        scope.launch {
          sheetState.hide()
          onDismiss()
        }
      },
    )
  }
}

/**
 * The sheet's body on the atmosphere. Separate from [DonateHeartsSheet] so
 * previews can render it without a sheet window.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DonateHeartsBody(
  cause: CompassionCause,
  ledger: HeartLedger,
  give: (amount: Int, causeId: String) -> Unit,
  onDone: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val state by ledger.state.collectAsStateWithLifecycle()
  val haptics = LocalHapticFeedback.current
  val density = LocalDensity.current
  val reduceMotion = rememberReduceMotion()
  val isTodayFull = state.isFullOn(ledger.today())

  // Set once hearts have gone: what was actually given, which may be less than
  // was asked. Fades the form back and lifts the hearts.
  var given by remember { mutableStateOf<Int?>(null) }
  // Follows `given` a beat behind, so the thanks blooms into a sheet the form
  // has already left rather than crossing it.
  var thanking by remember { mutableStateOf(false) }
  // What the thanks says, kept through its exit after a refusal clears `given`.
  var thanked by remember { mutableIntStateOf(0) }
  // The balance at the tap, held while the form steps back: giving the last
  // heart would otherwise drop the quick amounts and reflow the sheet under
  // the thanks.
  var heldBalance by remember { mutableIntStateOf(0) }
  val balance = if (given != null) heldBalance else state.balance
  // Each gift rolls its own field of hearts.
  var gifts by remember { mutableIntStateOf(0) }
  // Where this gift's hearts left from, frozen at the tap.
  var liftOff by remember { mutableStateOf<Offset?>(null) }
  val anchors = remember { LiftOffAnchors() }

  var amount by rememberSaveable { mutableIntStateOf(minOf(OPENING_AMOUNT, balance)) }
  // Whether the next digit starts a new number: true after a quick amount (and
  // for the opening suggestion), so typing over "All" writes what was typed.
  var entryIsFresh by rememberSaveable { mutableStateOf(true) }

  var firstAmount by remember { mutableStateOf(true) }
  LaunchedEffect(amount) {
    if (firstAmount) firstAmount = false else haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
  }
  // The second beat of a gift: once the form has stepped back, the thanks
  // blooms in. A refusal inside the beat cancels it.
  LaunchedEffect(given) {
    if (given == null) return@LaunchedEffect
    delay(THANKS_HOLD_MILLIS)
    thanking = true
  }

  val failure = state.spendFailure?.takeIf { it.categoryId == cause.id }
  // The server refused: the hearts are back in the balance, so the thanks
  // gives way to the form and its rollback caption.
  LaunchedEffect(failure) {
    if (failure != null && given != null) {
      given = null
      thanking = false
    }
  }

  val formAlpha = animateFloatAsState(if (given == null) 1f else 0f, bloom(), label = "donate-form-alpha")
  val formScale = animateFloatAsState(
    targetValue = if (given == null || reduceMotion) 1f else FORM_RECEDE_SCALE,
    animationSpec = bloom(),
    label = "donate-form-scale",
  )

  fun touch() = ledger.clearSpendFailure()

  // Typing past what you hold stops at what you hold.
  fun append(digit: Int) {
    touch()
    amount = minOf(if (entryIsFresh) digit else amount * 10 + digit, balance)
    entryIsFresh = false
  }

  // Gives, and lifts the hearts from the button the member just pressed. The
  // thanks follows a beat later; the sheet stays until they close it.
  fun donate() {
    val gift = minOf(amount, balance)
    if (gift <= 0 || given != null) return
    touch()
    give(gift, cause.id)
    haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
    liftOff = anchors.liftOff(with(density) { LIFT_OFF_INSET.toPx() })
    heldBalance = balance
    thanked = gift
    gifts += 1
    given = gift
  }

  Box(modifier.fillMaxWidth().onPlaced { anchors.body = it }) {
    AtmosphereBackground(Modifier.matchParentSize())

    Column(Modifier.fillMaxWidth()) {
      BottomSheetDefaults.DragHandle(
        color = Color.lavenderMist.copy(alpha = HANDLE_ALPHA),
        modifier = Modifier.align(Alignment.CenterHorizontally),
      )
      Column(
        Modifier
          .fillMaxWidth()
          // Once the hearts are gone the form steps back for the thanks:
          // hidden from TalkBack, still, and (below) closed to touches.
          .then(if (given != null) Modifier.clearAndSetSemantics {} else Modifier)
          .verticalScroll(rememberScrollState(), enabled = given == null)
          .graphicsLayer {
            alpha = formAlpha.value
            scaleX = formScale.value
            scaleY = formScale.value
            // Not an offscreen layer: one would cut the capsule's bloom square.
            compositingStrategy = CompositingStrategy.ModulateAlpha
          }
          .padding(horizontal = Dp.edge)
          .padding(top = 8.dp, bottom = Dp.rhythm)
          .navigationBarsPadding()
          .animateContentSize(settle()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
      ) {
        CauseRow(cause)
        Readout(amount = amount, balance = balance)

        if (balance > 0) {
          QuickAmounts(
            balance = balance,
            amount = amount,
            onPick = { value ->
              touch()
              amount = value
              entryIsFresh = true
            },
          )
        } else if (given == null) {
          // Where a member finds out there is nothing to send — the cause
          // card's capsule is live whatever the balance.
          EmptyNote(isTodayFull)
        }

        HeartAmountPad(
          enabled = given == null,
          onDigit = ::append,
          onDelete = {
            touch()
            amount /= 10
            entryIsFresh = false
          },
          onClear = {
            touch()
            amount = 0
            entryIsFresh = true
          },
        )

        HeartCapsule(
          title = stringResource(R.string.compassion_donate_hearts),
          enabled = given == null && amount > 0 && balance > 0,
          accessibilityLabel = pluralStringResource(R.plurals.donate_action_to, amount, amount, cause.name),
          onClick = ::donate,
          modifier = Modifier.onPlaced { anchors.action = it },
        )

        // A refused spend rolled back quietly; touching the pad clears it.
        AnimatedVisibility(visible = failure != null, enter = fadeIn(settle()), exit = fadeOut(settle())) {
          if (failure != null) RollbackCaption(failure)
        }
      }
    }

    if (given != null) {
      // Takes the form's touches without consuming them, so the sheet still
      // drags down from anywhere.
      Box(
        Modifier
          .matchParentSize()
          .pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent() } },
      )
    }

    AnimatedVisibility(
      visible = thanking,
      modifier = Modifier.matchParentSize(),
      enter = if (reduceMotion) fadeIn(bloom()) else fadeIn(bloom()) + scaleIn(bloom(), THANKS_BLOOM_FROM),
      exit = if (reduceMotion) fadeOut(bloom()) else fadeOut(bloom()) + scaleOut(bloom(), THANKS_BLOOM_FROM),
    ) {
      Box(Modifier.fillMaxSize().navigationBarsPadding(), contentAlignment = Alignment.Center) {
        GivingThanks(cause = cause, amount = thanked, onDone = onDone)
      }
    }

    val gift = given
    val origin = liftOff
    if (gift != null && origin != null && !reduceMotion) {
      key(gifts) {
        RisingHearts(count = RisingHeartsField.count(gift), origin = origin, modifier = Modifier.matchParentSize())
      }
    }
  }
}

/**
 * Where the hearts lift off from, read at the tap: the action capsule's top
 * centre in the body's own space, wherever the form has scrolled. Plain
 * fields, not state — nothing draws from them.
 */
private class LiftOffAnchors {
  var body: LayoutCoordinates? = null
  var action: LayoutCoordinates? = null

  fun liftOff(inset: Float): Offset? {
    val body = body?.takeIf { it.isAttached } ?: return null
    val action = action?.takeIf { it.isAttached } ?: return null
    return body.localPositionOf(action, Offset(action.size.width / 2f, inset))
  }
}

// MARK: - Cause

@Composable
private fun CauseRow(cause: CompassionCause) {
  Row(
    Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
    horizontalArrangement = Arrangement.spacedBy(14.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    CompassionMotif(symbol = cause.symbol, palette = cause.palette, cornerRadius = 14.dp, modifier = Modifier.size(48.dp))
    // Weighted, not followed by a Spacer, so a long name keeps its width.
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
      Text(cause.name, style = DeepType.sectionTitle, color = Color.deepPlum)
      Text(cause.tagline, style = DeepType.caption, color = Color.driftGrey)
    }
  }
}

// MARK: - Amount

/**
 * The chosen amount on its own axis, warmth gathered under the numeral. At
 * zero the numeral reads as an empty field (grey), not a shortfall.
 */
@Composable
private fun Readout(amount: Int, balance: Int) {
  val locale = rememberAppLocale()
  val label = stringResource(R.string.donate_amount_label)
  val value = stringResource(R.string.donate_amount_value, amount, balance)
  Column(
    Modifier.clearAndSetSemantics {
      contentDescription = label
      stateDescription = value
    },
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    Row(
      Modifier.drawBehind {
        drawCircle(
          brush = Brush.radialGradient(
            colors = listOf(Color.blushPowder.copy(alpha = READOUT_WARMTH_ALPHA), Color.Transparent),
            center = Offset(size.width / 2f, size.height / 2f),
            radius = READOUT_WARMTH_RADIUS.toPx(),
          ),
          radius = READOUT_WARMTH_RADIUS.toPx(),
        )
      },
      horizontalArrangement = Arrangement.spacedBy(10.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Icon(CompassionIcons.HeartFill, contentDescription = null, tint = Color.blushPowder, modifier = Modifier.size(22.dp))
      RollingText(
        text = AppFormat.number(amount, locale),
        value = amount.toFloat(),
        style = DeepType.bigNumber.copy(fontFeatureSettings = "tnum"),
        color = if (amount > 0) Color.deepPlum else Color.driftGrey,
      )
    }
    Text(
      stringResource(R.string.donate_hearts_you_hold, AppFormat.number(balance, locale)),
      style = DeepType.caption,
      color = Color.driftGrey,
    )
  }
}

/**
 * The amounts worth one tap. The ladder steps down for a small balance, and
 * "All" is offered only when it isn't already one of the steps.
 */
@Composable
private fun QuickAmounts(balance: Int, amount: Int, onPick: (Int) -> Unit) {
  val locale = rememberAppLocale()
  val ladder = (if (balance >= 10) listOf(10, 50, 100) else listOf(1, 5)).filter { it <= balance }
  Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
    ladder.forEach { value ->
      AmountChip(
        label = AppFormat.number(value, locale),
        spoken = pluralStringResource(R.plurals.donate_amount_hearts, value, value),
        selected = amount == value,
        onClick = { onPick(value) },
      )
    }
    if (balance !in ladder) {
      AmountChip(
        label = stringResource(R.string.donate_all),
        spoken = stringResource(R.string.donate_all_hearts, balance),
        selected = amount == balance,
        onClick = { onPick(balance) },
      )
    }
  }
}

@Composable
private fun RowScope.AmountChip(label: String, spoken: String, selected: Boolean, onClick: () -> Unit) {
  val shape = RoundedCornerShape(Dp.chip)
  Box(
    Modifier
      .weight(1f)
      .softPress()
      .background(
        if (selected) {
          Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder))
        } else {
          Brush.horizontalGradient(listOf(Color.White.copy(alpha = CHIP_FILL_ALPHA), Color.White.copy(alpha = CHIP_FILL_ALPHA)))
        },
        shape,
      )
      .combinedClickable(
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      .clearAndSetSemantics {
        contentDescription = spoken
        this.selected = selected
      }
      .padding(horizontal = 14.dp, vertical = 10.dp),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      label,
      style = DeepType.caption.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, fontFeatureSettings = "tnum"),
      color = if (selected) Color.White else Color.deepPlum,
      maxLines = 1,
    )
  }
}

/**
 * "Practice earns more" holds only while the day still has hearts in it — a
 * promise of a heart that isn't coming is exactly what the completion screen
 * refuses to make.
 */
@Composable
private fun EmptyNote(isTodayFull: Boolean) {
  Column(
    Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(4.dp),
  ) {
    Text(stringResource(R.string.donate_no_hearts), style = DeepType.sectionTitle, color = Color.deepPlum, textAlign = TextAlign.Center)
    Text(
      stringResource(if (isTodayFull) R.string.donate_today_full else R.string.donate_practice_earns),
      style = DeepType.caption,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
  }
}

// MARK: - Pad

/**
 * The soft number pad: pebble keys, the same inset tonal panel that groups
 * anything else inside a DEEP card. The bottom-left cell is left empty rather
 * than given a "clear" key — holding delete does that.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HeartAmountPad(
  enabled: Boolean,
  onDigit: (Int) -> Unit,
  onDelete: () -> Unit,
  onClear: () -> Unit,
) {
  val locale = rememberAppLocale()
  val deleteLabel = stringResource(R.string.donate_delete)
  val clearLabel = stringResource(R.string.donate_hold_to_clear)
  Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(KEY_SPACING)) {
    DIGITS.forEach { row ->
      Row(horizontalArrangement = Arrangement.spacedBy(KEY_SPACING)) {
        row.forEach { digit -> DigitKey(AppFormat.number(digit, locale), enabled) { onDigit(digit) } }
      }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(KEY_SPACING)) {
      Spacer(Modifier.weight(1f).height(KEY_HEIGHT))
      DigitKey(AppFormat.number(0, locale), enabled) { onDigit(0) }
      Box(
        Modifier
          .weight(1f)
          .height(KEY_HEIGHT)
          .softPress()
          .pebble(cornerRadius = Dp.tile)
          .combinedClickable(
            enabled = enabled,
            role = Role.Button,
            onClickLabel = deleteLabel,
            onLongClickLabel = clearLabel,
            interactionSource = null,
            indication = null,
            onLongClick = onClear,
            onClick = onDelete,
          )
          .semantics { contentDescription = deleteLabel },
        contentAlignment = Alignment.Center,
      ) {
        Icon(CompassionIcons.DeleteLeft, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(20.dp))
      }
    }
  }
}

@Composable
private fun RowScope.DigitKey(label: String, enabled: Boolean, onClick: () -> Unit) {
  Box(
    Modifier
      .weight(1f)
      .height(KEY_HEIGHT)
      .softPress()
      .pebble(cornerRadius = Dp.tile)
      .combinedClickable(
        enabled = enabled,
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Text(label, style = DeepType.counter.copy(fontFeatureSettings = "tnum"), color = Color.deepPlum)
  }
}

// MARK: - Previews

@Composable
private fun DonatePreview(causeId: String, ledger: (Clock, ZoneId) -> HeartLedger) {
  val held = remember { ledger(Clock.systemDefaultZone(), ZoneId.systemDefault()) }
  DeepTheme {
    val cause = rememberCompassionContent().cause(causeId)!!
    Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.BottomCenter) {
      DonateHeartsBody(cause = cause, ledger = held, give = { _, _ -> }, onDone = {})
    }
  }
}

@Preview(showBackground = true, name = "Donate hearts", heightDp = 900)
@Composable
private fun DonateHeartsPreview() = DonatePreview("healthcare", HeartLedger.Companion::sample)

/** A balance below the standard ladder: the quick amounts step down and "All" carries it. */
@Preview(showBackground = true, name = "Donate hearts — small balance", heightDp = 900)
@Composable
private fun DonateHeartsSmallPreview() = DonatePreview("nature", HeartLedger.Companion::small)

/** Empty with the day's thirty already earned — practice can't top it up until tomorrow. */
@Preview(showBackground = true, name = "Donate hearts — no hearts left", heightDp = 900)
@Composable
private fun DonateHeartsSpentPreview() = DonatePreview("education", HeartLedger.Companion::spent)

/** Empty, but the day is still open, so the caption points at the next practice. */
@Preview(showBackground = true, name = "Donate hearts — spent, day open", heightDp = 900)
@Composable
private fun DonateHeartsSpentOpenPreview() = DonatePreview("peace", HeartLedger.Companion::spentDayOpen)

@Preview(showBackground = true, name = "Donate hearts — send refused", heightDp = 900)
@Composable
private fun DonateHeartsRefusedPreview() = DonatePreview("nature", HeartLedger.Companion::sendRefused)

@Preview(showBackground = true, name = "Donate hearts — large type", heightDp = 1100, fontScale = 1.4f)
@Composable
private fun DonateHeartsLargeTypePreview() = DonatePreview("peace", HeartLedger.Companion::sample)
