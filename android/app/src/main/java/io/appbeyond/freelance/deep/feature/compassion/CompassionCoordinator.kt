package io.appbeyond.freelance.deep.feature.compassion

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.theme.DeepTheme
import java.time.Clock
import java.time.ZoneId

/**
 * The Compassion tab's composition root: it presents the donate sheet over the
 * portfolio home, and nothing else.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/CompassionPortfolioCoordinatorView.swift.
 * The tab's back stack lives in `MainShellCoordinator`, as every tab's does,
 * so the cause detail is a shell route (`DeepRoute.CompassionCause`) reached
 * through [onOpenCause]. That route is **parked**, exactly as iOS parks
 * `openCategory`: nothing calls it while giving happens on the cause cards, and
 * the screen stays one call away from returning.
 *
 * Styling stays out of here; the home screen paints its own atmosphere.
 *
 * @param give sends hearts on a scope that outlives the sheet.
 * @param onRefresh the hero pull — the garden refresh the wallet rides.
 * @param onOpenCause pushes a cause's detail (parked — see above).
 */
@Composable
fun CompassionCoordinator(
  ledger: HeartLedger,
  give: (amount: Int, causeId: String, projectId: String?) -> Unit,
  onRefresh: suspend () -> Unit,
  modifier: Modifier = Modifier,
  @Suppress("UNUSED_PARAMETER") onOpenCause: (String) -> Unit = {},
) {
  var donatingTo by rememberSaveable { mutableStateOf<String?>(null) }
  val content = rememberCompassionContent()

  CompassionPortfolioHomeScreen(
    ledger = ledger,
    onDonate = { donatingTo = it.id },
    onRefresh = onRefresh,
    modifier = modifier,
  )

  val cause = donatingTo?.let(content::cause)
  if (cause != null) {
    DonateHeartsSheet(
      cause = cause,
      ledger = ledger,
      give = { amount, causeId -> give(amount, causeId, null) },
      onDismiss = { donatingTo = null },
    )
  }
}

@Preview(showBackground = true, name = "Compassion — portfolio")
@Composable
private fun CompassionCoordinatorPreview() {
  val ledger = remember { HeartLedger.sample(Clock.systemDefaultZone(), ZoneId.systemDefault()) }
  DeepTheme {
    CompassionCoordinator(ledger = ledger, give = { _, _, _ -> }, onRefresh = {})
  }
}

@Preview(showBackground = true, name = "Compassion — no hearts left")
@Composable
private fun CompassionCoordinatorSpentPreview() {
  val ledger = remember { HeartLedger.spent(Clock.systemDefaultZone(), ZoneId.systemDefault()) }
  DeepTheme {
    CompassionCoordinator(ledger = ledger, give = { _, _, _ -> }, onRefresh = {})
  }
}
