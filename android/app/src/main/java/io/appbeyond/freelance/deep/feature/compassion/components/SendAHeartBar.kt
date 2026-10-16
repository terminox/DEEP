package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.HeartBurst
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.settle

/** The trailing count on the capsule — iOS's `.opacity(0.85)`. */
private const val TRAILING_ALPHA = 0.85f

/**
 * The cause detail's primary action, pinned to the bottom: send a heart to
 * the whole cause in one tap.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/SendAHeartBar.swift,
 * with one deliberate change: iOS swaps the spent capsule for a frosted "No
 * hearts left" note. DEEP's action buttons keep one title for the life of a
 * screen, so here the capsule stays "Send a heart" and dims, and its trailing
 * words say why ("Practice earns more").
 *
 * @param failure a refused spend for *this* cause, read for the quiet caption.
 */
@Composable
fun SendAHeartBar(
  causeName: String,
  balance: Int,
  failure: HeartLedger.SpendFailure?,
  onSend: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val locale = rememberAppLocale()
  var burst by remember { mutableIntStateOf(0) }
  val canGive = balance > 0
  Column(
    modifier.fillMaxWidth().padding(horizontal = Dp.edge).padding(bottom = 6.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    HeartBurst(trigger = burst) {
      HeartCapsule(
        title = stringResource(R.string.compassion_send_a_heart),
        enabled = canGive,
        accessibilityLabel = stringResource(R.string.compassion_send_a_heart_to, causeName),
        onClick = {
          onSend()
          burst += 1
        },
      ) {
        Text(
          text = if (canGive) {
            stringResource(R.string.compassion_hearts_left, AppFormat.number(balance, locale))
          } else {
            stringResource(R.string.compassion_practice_earns_more)
          },
          style = FactMediumStyle,
          color = Color.White.copy(alpha = TRAILING_ALPHA),
          maxLines = 1,
        )
      }
    }

    // A refused spend rolled back quietly; the next send clears the caption.
    AnimatedVisibility(visible = failure != null, enter = fadeIn(settle()), exit = fadeOut(settle())) {
      if (failure != null) RollbackCaption(failure)
    }
  }
}

/** "That heart couldn't be sent — it's back in your balance." */
@Composable
internal fun RollbackCaption(failure: HeartLedger.SpendFailure, modifier: Modifier = Modifier) {
  val locale = rememberAppLocale()
  Text(
    text = pluralStringResource(R.plurals.compassion_rollback, failure.amount, AppFormat.number(failure.amount, locale)),
    style = DeepType.caption,
    color = Color.driftGrey,
    textAlign = TextAlign.Center,
    modifier = modifier,
  )
}

@Preview(showBackground = true, name = "Send a heart bar")
@Composable
private fun SendAHeartBarPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    Column(Modifier.align(Alignment.BottomCenter), verticalArrangement = Arrangement.spacedBy(12.dp)) {
      SendAHeartBar(causeName = "Nature", balance = 2_450, failure = null, onSend = {})
      SendAHeartBar(causeName = "Nature", balance = 0, failure = null, onSend = {})
      SendAHeartBar(
        causeName = "Nature",
        balance = 2_449,
        failure = HeartLedger.SpendFailure(amount = 1, categoryId = "nature"),
        onSend = {},
      )
    }
  }
}
