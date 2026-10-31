package io.appbeyond.freelance.deep.feature.deepsound.components

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.feature.rewards.store.ListenNotice
import io.appbeyond.freelance.deep.feature.rewards.store.ListenReporting
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.moonCream

// MARK: - Constants

/** The heart beside the words — iOS's 12pt semibold `heart.fill`. */
private val HEART_GLYPH = 12.dp

/** iOS's `HStack(spacing: 6)` — `HeartBalanceChip`'s pairing. */
private val HEART_SPACING = 6.dp

// MARK: - Label

/**
 * The player chrome's word about a listen's heart — "+1 heart", or that
 * today's track hearts are all in. Paired exactly as [HeartBalanceChip][io.appbeyond.freelance.deep.feature.compassion.components.HeartBalanceChip]
 * pairs its icon and figure: a small blush heart beside the text, so a heart
 * reads the same wherever the app shows one. The caller picks the type so the
 * label sits in the line it replaces.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/ListenNoticeLabel.swift.
 *
 * @param ink plum on DEEP's pale surfaces, cream over Now Playing's photograph.
 * @param compact the mini player's tight line: today's hearts read as a count
 *   ("3/3 hearts today") rather than the sentence Now Playing has room for.
 *   The full sentence is still what TalkBack hears ([ListenNoticeAnnouncer]).
 */
@Composable
fun ListenNoticeLabel(
  notice: ListenNotice,
  style: TextStyle,
  modifier: Modifier = Modifier,
  ink: Color = Color.deepPlum,
  compact: Boolean = false,
) {
  Row(
    modifier,
    horizontalArrangement = Arrangement.spacedBy(HEART_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = CompassionIcons.HeartFill,
      contentDescription = null,
      tint = Color.blushPowder,
      modifier = Modifier.size(HEART_GLYPH),
    )
    Text(
      text = listenNoticeMessage(notice.kind, compact),
      style = style,
      color = ink,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
    )
  }
}

@Composable
private fun listenNoticeMessage(kind: ListenNotice.Kind, compact: Boolean): String = when (kind) {
  ListenNotice.Kind.Earned -> stringResource(R.string.player_listen_earned)
  is ListenNotice.Kind.DayComplete -> if (compact) {
    stringResource(R.string.player_listen_day_complete_compact, kind.perDay, kind.perDay)
  } else {
    stringResource(R.string.player_listen_day_complete, kind.perDay)
  }
}

/** What TalkBack says for a notice: the full sentence, never the compact count. */
@Composable
private fun listenNoticeAnnouncement(kind: ListenNotice.Kind): String = when (kind) {
  ListenNotice.Kind.Earned -> stringResource(R.string.player_listen_earned_a11y)
  is ListenNotice.Kind.DayComplete -> stringResource(R.string.player_listen_day_complete, kind.perDay)
}

// MARK: - The line it swaps into

/**
 * A subtitle line that gives way, for a few seconds, to a listen's heart:
 * [subtitle] normally, [label] while [notice] shows — cross-fading on
 * [exhale] each way, and between two notices in a row.
 */
@Composable
fun ListenNoticeLine(
  notice: ListenNotice?,
  modifier: Modifier = Modifier,
  label: @Composable (ListenNotice) -> Unit,
  subtitle: @Composable () -> Unit,
) {
  Crossfade(targetState = notice, modifier = modifier, animationSpec = exhale(), label = "listen-notice") { shown ->
    if (shown != null) label(shown) else subtitle()
  }
}

// MARK: - Feeling it

/**
 * Feels a newly earned heart — claimed through [reporter], so the heart is
 * felt once even while Now Playing and the mini player are both composed —
 * and returns a count that ticks for each one, for a [HeartBurst][io.appbeyond.freelance.deep.shared.components.HeartBurst]
 * to bloom on. Only a change counts: a surface opened while a notice is
 * already showing neither buzzes nor blooms (iOS's `onChange(of: notice?.id)`).
 */
@Composable
fun rememberListenHeart(reporter: ListenReporting, notice: ListenNotice?): Int {
  val haptics = LocalHapticFeedback.current
  var bloom by remember { mutableIntStateOf(0) }
  var seenId by remember { mutableStateOf(notice?.id) }
  LaunchedEffect(notice?.id) {
    if (notice == null || notice.id == seenId) return@LaunchedEffect
    seenId = notice.id
    if (notice.kind != ListenNotice.Kind.Earned) return@LaunchedEffect
    bloom++
    if (reporter.claimHaptic(notice)) haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
  }
  return bloom
}

// MARK: - Saying it

/**
 * Speaks each notice to TalkBack once, as it appears — iOS's
 * `AccessibilityNotification.Announcement`. Composed once, by the shell, so
 * the mini player and Now Playing never both announce it; the words resolve
 * here, in the language the member reads in.
 */
@Composable
fun ListenNoticeAnnouncer(reporter: ListenReporting) {
  val notice by reporter.notice.collectAsStateWithLifecycle()
  val context = LocalContext.current
  val message = notice?.let { listenNoticeAnnouncement(it.kind) }
  LaunchedEffect(notice?.id) {
    if (message != null) announce(context, message)
  }
}

/**
 * An accessibility announcement through the system's manager. Not
 * `View.announceForAccessibility`, deprecated in API 36; a notice that comes
 * and goes on its own has no node a live region could ride on in both
 * surfaces at once.
 */
private fun announce(context: Context, message: String) {
  val manager = context.getSystemService(AccessibilityManager::class.java) ?: return
  if (!manager.isEnabled) return
  val event = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
    AccessibilityEvent(AccessibilityEvent.TYPE_ANNOUNCEMENT)
  } else {
    @Suppress("DEPRECATION")
    AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
  }
  event.packageName = context.packageName
  event.text.add(message)
  manager.sendAccessibilityEvent(event)
}

// MARK: - Previews

@Preview(showBackground = true, name = "Listen notice")
@Composable
private fun ListenNoticeLabelPreview() {
  val dayComplete = ListenNotice(2, ListenNotice.Kind.DayComplete(RewardRules.trackDailyLimit))
  DeepTheme {
    Column(
      Modifier.background(Color.moonCream).padding(Dp.edge),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      ListenNoticeLabel(ListenNotice(1, ListenNotice.Kind.Earned), style = DeepType.micro)
      ListenNoticeLabel(dayComplete, style = DeepType.micro)
      ListenNoticeLabel(dayComplete, style = DeepType.micro, compact = true)
      ListenNoticeLabel(ListenNotice(1, ListenNotice.Kind.Earned), style = DeepType.body)
    }
  }
}

@Preview(showBackground = true, name = "Listen notice — Thai", locale = "th")
@Composable
private fun ListenNoticeLabelThaiPreview() {
  ListenNoticeLabelPreview()
}

@Preview(showBackground = true, name = "Listen notice — over Now Playing")
@Composable
private fun ListenNoticeLabelCreamPreview() {
  DeepTheme {
    Column(
      Modifier.background(Color.deepPlum).padding(Dp.edge),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      ListenNoticeLabel(ListenNotice(1, ListenNotice.Kind.Earned), style = DeepType.body, ink = Color.moonCream)
      ListenNoticeLabel(
        ListenNotice(2, ListenNotice.Kind.DayComplete(RewardRules.trackDailyLimit)),
        style = DeepType.body,
        ink = Color.moonCream,
      )
    }
  }
}
