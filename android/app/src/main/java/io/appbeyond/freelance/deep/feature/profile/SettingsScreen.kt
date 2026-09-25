package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.BuildConfig
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// MARK: - Constants

/** iOS `.padding(.bottom, 40)` under the last card. */
private val SCROLL_BOTTOM_INSET = 40.dp

private val TOP_BAR_PADDING_VERTICAL = 6.dp

private val AVATAR_SIZE = 64.dp
private val AVATAR_RIM = 1.dp
private const val AVATAR_RIM_ALPHA = 0.6f

/** The avatar's lift — iOS's `shadow(color: .lavenderMist.opacity(0.4), radius: 18, y: 8)`. */
private const val AVATAR_GLOW_ALPHA = 0.4f
private val AVATAR_GLOW_SPREAD = 18.dp
private val AVATAR_GLOW_OFFSET_Y = 8.dp
private const val AVATAR_GLOW_STEPS = 6

private val PLAN_CHIP_PADDING_HORIZONTAL = 12.dp
private val PLAN_CHIP_PADDING_VERTICAL = 6.dp
private const val PLAN_CHIP_FILL_ALPHA = 0.5f
private val PLAN_CHIP_GLYPH = 12.dp

private const val FOOTER_ALPHA = 0.8f

// MARK: - Screen

/**
 * The system settings, pushed from the You tab — identity (with the
 * non-actionable plan chip) up top, then Calm-inspired cards of rows:
 * preferences, membership, and account, closing on a quiet version footer.
 *
 * Ported from Deep/Deep/Features/Profile/SettingsView.swift. It reads the
 * *shared* stores, so logging out here flips the gate `AppRoot` watches and
 * crossfades back to the welcome flow — this screen never navigates anywhere
 * itself on the way out.
 *
 * Deliberate gaps against iOS, each a product decision rather than an
 * omission:
 * - **Preferences and Membership are UI only.** The rows are real, press, and
 *   do nothing: there is no language persistence, reminder scheduling or Play
 *   Billing on Android yet. The daily-reminder row shows the "off" chevron
 *   because nothing can be on. The restore row's progress / "Restored" states
 *   are not ported for the same reason.
 * - **The plan chip always reads "Free plan"** — no subscription store exists
 *   to ask. iOS's "Checking…" state has nothing to check.
 * - **Log out resets onboarding only.** iOS also clears the practice journal,
 *   garden, ledger, playlist and reminder queue; none of those stores exist on
 *   Android yet. Each must join both exits below as it lands.
 *
 * The back control is our own frosted chevron. On iOS that choice would cost
 * the interactive edge-swipe pop; on Android system back is independent of the
 * control and pops the You tab's stack in `MainShellCoordinator`.
 *
 * @param language the language Deep currently reads in, named by its endonym.
 */
@Composable
fun SettingsScreen(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  language: AppLanguage,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val account by accountStore.account.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()

  var confirmingLogOut by remember { mutableStateOf(false) }
  var confirmingDelete by remember { mutableStateOf(false) }
  var isDeletingAccount by remember { mutableStateOf(false) }
  var deleteFailed by remember { mutableStateOf(false) }

  // Both exits run NonCancellable. Signing out flips the root phase, which
  // retires this whole shell (and this screen's scope) as it crossfades away;
  // the onboarding reset after it must still land, or a later launch would
  // reopen a signed-out member on a "completed" onboarding.
  fun logOut() {
    scope.launch {
      withContext(NonCancellable) {
        accountStore.logOut()
        // Resetting onboarding flips `hasCompletedOnboarding`, which AppRoot
        // observes — together with the now signed-out state it crossfades back
        // to the welcome flow.
        onboardingStore.reset()
      }
    }
  }

  fun deleteAccount() {
    isDeletingAccount = true
    scope.launch {
      withContext(NonCancellable) {
        try {
          accountStore.deleteAccount()
          // Same exit as log out; the shell crossfades to the welcome flow, so
          // the in-flight state never needs resetting on success.
          onboardingStore.reset()
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (_: Exception) {
          // The store clears nothing when DELETE /me fails, so neither do we.
          isDeletingAccount = false
          deleteFailed = true
        }
      }
    }
  }

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      SettingsTopBar(onBack = onBack)

      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(horizontal = Dp.edge)
          .padding(top = Dp.rhythm, bottom = SCROLL_BOTTOM_INSET),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        IdentityHeader(account)

        SettingsSection(title = stringResource(R.string.settings_section_preferences)) {
          SettingsRow(
            title = stringResource(R.string.settings_language),
            icon = DeepIcons.Globe,
            accessory = SettingsAccessory.Value(language.endonym),
            onClick = {},
          )
          SettingsRow(
            title = stringResource(R.string.settings_daily_reminder),
            icon = ProfileIcons.Bell,
            accessory = SettingsAccessory.Chevron,
            onClick = {},
          )
        }

        SettingsSection(title = stringResource(R.string.settings_section_membership)) {
          SettingsRow(
            title = stringResource(R.string.settings_manage_subscription),
            icon = ProfileIcons.CreditCard,
            accessory = SettingsAccessory.Chevron,
            onClick = {},
          )
          SettingsRow(
            title = stringResource(R.string.settings_restore_purchases),
            icon = ProfileIcons.ArrowClockwise,
            onClick = {},
          )
        }

        SettingsSection(title = stringResource(R.string.settings_section_account)) {
          SettingsRow(
            title = stringResource(R.string.settings_log_out),
            icon = ProfileIcons.LogOut,
            onClick = { confirmingLogOut = true },
          )
          SettingsRow(
            title = stringResource(R.string.settings_delete_account),
            icon = ProfileIcons.Trash,
            accessory = if (isDeletingAccount) SettingsAccessory.Progress else SettingsAccessory.None,
            tint = Color.duskRose,
            onClick = { if (!isDeletingAccount) confirmingDelete = true },
          )
        }

        Text(
          text = stringResource(R.string.settings_version, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE),
          style = DeepType.micro,
          color = Color.driftGrey.copy(alpha = FOOTER_ALPHA),
          modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp),
        )
      }
    }
  }

  if (confirmingLogOut) {
    DeepConfirmDialog(
      title = stringResource(R.string.settings_log_out_title),
      message = stringResource(R.string.settings_log_out_body),
      actions = listOf(
        DialogAction(stringResource(R.string.settings_log_out_stay)) { confirmingLogOut = false },
        DialogAction(stringResource(R.string.settings_log_out_confirm), destructive = true) {
          confirmingLogOut = false
          logOut()
        },
      ),
      onDismissRequest = { confirmingLogOut = false },
    )
  }

  if (confirmingDelete) {
    DeepConfirmDialog(
      title = stringResource(R.string.settings_delete_title),
      message = stringResource(R.string.settings_delete_body),
      actions = listOf(
        DialogAction(stringResource(R.string.settings_delete_cancel)) { confirmingDelete = false },
        DialogAction(stringResource(R.string.settings_delete_confirm), destructive = true) {
          confirmingDelete = false
          deleteAccount()
        },
      ),
      onDismissRequest = { confirmingDelete = false },
    )
  }

  if (deleteFailed) {
    DeepConfirmDialog(
      title = stringResource(R.string.settings_delete_failed_title),
      message = stringResource(R.string.settings_delete_failed_body),
      actions = listOf(DialogAction(stringResource(R.string.settings_ok)) { deleteFailed = false }),
      onDismissRequest = { deleteFailed = false },
    )
  }
}

// MARK: - Top bar

/**
 * Back chevron at the leading edge, the title centred over the whole width —
 * the shape of iOS's inline navigation bar, with no bar background, so the
 * atmosphere runs up behind it as it does under iOS's hidden toolbar
 * background.
 */
@Composable
private fun SettingsTopBar(onBack: () -> Unit) {
  Box(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = TOP_BAR_PADDING_VERTICAL),
    contentAlignment = Alignment.Center,
  ) {
    HeaderIconButton(
      icon = ProfileIcons.ChevronLeft,
      contentDescription = stringResource(R.string.settings_back),
      onClick = onBack,
      modifier = Modifier.align(Alignment.CenterStart),
    )
    Text(
      text = stringResource(R.string.settings_title),
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
    )
  }
}

// MARK: - Identity

@Composable
private fun IdentityHeader(account: Account?) {
  val displayName = account?.displayName ?: stringResource(R.string.settings_friend)
  val initials = (account ?: Account.Placeholder).initials

  Column(
    Modifier
      .fillMaxWidth()
      .padding(top = Dp.rhythm, bottom = 8.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    Avatar(initials, Modifier.padding(bottom = 6.dp))

    Text(text = displayName, style = DeepType.displayTitle, color = Color.deepPlum)

    // Email is the only sign-in method on Android, so there is no "Signed in
    // with Apple" branch; an account restored offline as the placeholder has
    // an empty email and simply shows none.
    val email = account?.email.orEmpty()
    if (email.isNotEmpty()) {
      Text(text = email, style = DeepType.caption, color = Color.driftGrey)
    }

    PlanChip(Modifier.padding(top = 4.dp))
  }
}

/** The dusk artwork palette, lavender to blush, with initials in light serif. */
@Composable
private fun Avatar(initials: String, modifier: Modifier = Modifier) {
  Box(
    modifier
      .size(AVATAR_SIZE)
      .avatarGlow()
      .clip(CircleShape)
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.blushPowder)))
      .border(AVATAR_RIM, Color.White.copy(alpha = AVATAR_RIM_ALPHA), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Text(text = initials, style = DeepType.displayTitle, color = Color.White)
  }
}

/**
 * The soft lavender lift under the avatar, drawn as stacked fading discs for
 * the reason `frostedCard` draws its bloom that way: a platform shadow reads as
 * hard grey here, and `Modifier.blur` is a no-op below API 31.
 */
private fun Modifier.avatarGlow(): Modifier = drawBehind {
  val radius = size.minDimension / 2f
  val spread = AVATAR_GLOW_SPREAD.toPx()
  val center = Offset(size.width / 2f, size.height / 2f + AVATAR_GLOW_OFFSET_Y.toPx())
  for (step in AVATAR_GLOW_STEPS downTo 1) {
    val t = step / AVATAR_GLOW_STEPS.toFloat()
    drawCircle(
      color = Color.lavenderMist.copy(alpha = AVATAR_GLOW_ALPHA * (1f - t) * (1f - t)),
      radius = radius + spread * t,
      center = center,
    )
  }
}

/**
 * The non-actionable membership status, worn as part of the identity — the
 * cards below stay purely actionable.
 */
@Composable
private fun PlanChip(modifier: Modifier = Modifier) {
  Row(
    modifier
      .clip(RoundedCornerShape(Dp.chip))
      .background(Color.White.copy(alpha = PLAN_CHIP_FILL_ALPHA))
      .padding(horizontal = PLAN_CHIP_PADDING_HORIZONTAL, vertical = PLAN_CHIP_PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(6.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = ProfileIcons.Sparkles,
      contentDescription = null,
      tint = Color.driftGrey,
      modifier = Modifier.size(PLAN_CHIP_GLYPH),
    )
    Text(text = stringResource(R.string.settings_free_plan), style = DeepType.micro, color = Color.driftGrey)
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Settings — email user")
@Composable
private fun SettingsScreenPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      SettingsScreen(
        accountStore = MockAccountStore.emailUser,
        onboardingStore = MockOnboardingProgressStore.fresh,
        language = AppLanguage.English,
        onBack = {},
      )
    }
  }
}

@Preview(showBackground = true, name = "Settings — signed out, Thai")
@Composable
private fun SettingsScreenSignedOutPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      SettingsScreen(
        accountStore = MockAccountStore.signedOut,
        onboardingStore = MockOnboardingProgressStore.fresh,
        language = AppLanguage.Thai,
        onBack = {},
      )
    }
  }
}
