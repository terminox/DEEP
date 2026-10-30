package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
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
import io.appbeyond.freelance.deep.feature.premium.LocalPremiumAccess
import io.appbeyond.freelance.deep.feature.premium.LocalSubscriptionStore
import io.appbeyond.freelance.deep.feature.premium.model.DeepProduct
import io.appbeyond.freelance.deep.feature.premium.model.PlanLabel
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionManagement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import io.appbeyond.freelance.deep.feature.premium.store.FakePremiumAccess
import io.appbeyond.freelance.deep.feature.premium.store.PreviewSubscriptionStore
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.feature.reminders.model.DailyReminder
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.NOTE_HOLD_MILLIS
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
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
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
private val AVATAR_GLOW_RADIUS = 18.dp
private val AVATAR_GLOW_OFFSET_Y = 8.dp

private val PLAN_CHIP_PADDING_HORIZONTAL = 12.dp
private val PLAN_CHIP_PADDING_VERTICAL = 6.dp
private const val PLAN_CHIP_FILL_ALPHA = 0.5f
private val PLAN_CHIP_GLYPH = 12.dp

private const val FOOTER_ALPHA = 0.8f

/** The gap between the membership card and the quiet line under it — iOS's `VStack(spacing: 8)`. */
private val MEMBERSHIP_NOTE_SPACING = 8.dp
private val MEMBERSHIP_NOTE_INSET = 8.dp

/** Where a restore stands — iOS's `RestorePhase`. */
private enum class RestorePhase { Idle, Working, Restored, Failed }

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
 * **Membership.** The plan chip reads the store and the one premium answer
 * ([LocalSubscriptionStore], [LocalPremiumAccess]): the plan by name when the
 * store sees it, "DEEP Premium" for a membership only the server knows,
 * "Free plan" once the store has answered, "Checking…" until then. The
 * Membership card offers "Manage subscription" to members only — Google
 * Play's page for a Play purchase, the page RevenueCat names for one made
 * elsewhere ([SubscriptionManagement.forMember]) — and "Restore purchases" to
 * everyone; a restore that finds a membership is confirmed with the server
 * the way a purchase is (`PremiumAccess.didPurchase`), so withheld audio
 * arrives without waiting for the next foreground.
 *
 * Deliberate gaps against iOS, each a product decision rather than an
 * omission:
 * - **Upgrade to DEEP Premium** shows only once [onUpgrade] is handed in —
 *   the paywall's own work. Until then a member on the free plan sees Restore
 *   alone.
 * - **Both exits reset onboarding and every account store** (practice journal,
 *   listen queue, garden, heart ledger, continuity day, and the daily reminder —
 *   [resetAccountState]); the playlist and the player are cleared by
 *   `AppDependencies`' account watcher. A store that lands later must join
 *   both exits below.
 *
 * Log out first offers unsynced practice and queued listens to the server
 * ([flushBeforeLogOut], three seconds, side by side) while the token still
 * works, with a spinner on the row. If anything is still left, the member is
 * asked before it is lost — "Some practice hasn't synced yet", Log out anyway
 * or Stay — as iOS asks. Account deletion skips it: the server is about to
 * delete the practice anyway.
 *
 * The back control is our own frosted chevron. On iOS that choice would cost
 * the interactive edge-swipe pop; on Android system back is independent of the
 * control and pops the You tab's stack in `MainShellCoordinator`.
 *
 * @param language the language DEEP currently reads in, named by its endonym.
 * @param reminder the daily reminder's settings — the row shows its time while on.
 * @param onOpenLanguage / onOpenReminder push the two preference screens.
 * @param flushBeforeLogOut offers unsynced practice and queued listens to the
 *   server, bounded; true when nothing is left behind. Run before log out
 *   ends the session.
 * @param resetAccountState forgets the member's account state (rewards and
 *   the reminder), run after either exit succeeds.
 * @param onUpgrade opens the DEEP Premium invitation — the Membership card's
 *   first row, shown on the free plan once this is supplied (iOS's
 *   `openPaywall(.settings)`). Null hides it.
 */
@Composable
fun SettingsScreen(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  language: AppLanguage,
  reminder: DailyReminder,
  flushBeforeLogOut: suspend () -> Boolean,
  resetAccountState: suspend () -> Unit,
  onOpenLanguage: () -> Unit,
  onOpenReminder: () -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
  onUpgrade: (() -> Unit)? = null,
) {
  val locale = rememberAppLocale()
  val account by accountStore.account.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()

  val subscriptionStore = LocalSubscriptionStore.current
  val premiumAccess = LocalPremiumAccess.current
  val storeStatus by subscriptionStore.status.collectAsStateWithLifecycle()
  val storeManagement by subscriptionStore.management.collectAsStateWithLifecycle()
  val hasPremium by premiumAccess.hasPremium.collectAsStateWithLifecycle()
  val serverEntitlement by premiumAccess.entitlement.collectAsStateWithLifecycle()
  val uriHandler = LocalUriHandler.current
  val packageName = LocalContext.current.packageName
  var restorePhase by remember { mutableStateOf(RestorePhase.Idle) }

  var confirmingLogOut by remember { mutableStateOf(false) }
  var isLoggingOut by remember { mutableStateOf(false) }
  var confirmingUnsynced by remember { mutableStateOf(false) }
  var confirmingDelete by remember { mutableStateOf(false) }
  var isDeletingAccount by remember { mutableStateOf(false) }
  var deleteFailed by remember { mutableStateOf(false) }

  // Both exits run NonCancellable. Signing out flips the root phase, which
  // retires this whole shell (and this screen's scope) as it crossfades away;
  // the resets after it must still land, or a later launch would reopen a
  // signed-out member on a "completed" onboarding, or the next member on the
  // last one's garden.
  suspend fun completeLogOut() {
    isLoggingOut = true
    accountStore.logOut()
    // Resetting onboarding flips `hasCompletedOnboarding`, which AppRoot
    // observes — together with the now signed-out state it crossfades back
    // to the welcome flow.
    onboardingStore.reset()
    resetAccountState()
  }

  // Gives unsynced practice and queued listens one last chance to reach the
  // server while the session's token still works — the journal and the queue
  // leave with the account. If either still can't land, the member is asked
  // before anything is lost.
  fun logOut() {
    if (isLoggingOut) return
    isLoggingOut = true
    scope.launch {
      withContext(NonCancellable) {
        if (flushBeforeLogOut()) {
          completeLogOut()
        } else {
          isLoggingOut = false
          confirmingUnsynced = true
        }
      }
    }
  }

  fun logOutAnyway() {
    scope.launch { withContext(NonCancellable) { completeLogOut() } }
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
          resetAccountState()
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

  /** Google Play's page for a Play purchase; the page RevenueCat names for anything bought elsewhere. */
  fun manageSubscription() {
    val management = SubscriptionManagement.forMember(storeStatus, storeManagement, serverEntitlement)
    runCatching { uriHandler.openUri(management.url(packageName)) }
  }

  fun restorePurchases() {
    if (restorePhase == RestorePhase.Working) return
    restorePhase = RestorePhase.Working
    scope.launch {
      try {
        subscriptionStore.restore()
        restorePhase = RestorePhase.Restored
        // Confirmed with the server the way a purchase is, so the audio it
        // withholds is released without waiting for the next foreground.
        if (subscriptionStore.status.value.isSubscribed) premiumAccess.didPurchase()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        restorePhase = RestorePhase.Failed
      }
      delay(NOTE_HOLD_MILLIS)
      restorePhase = RestorePhase.Idle
    }
  }

  val scroll = rememberScrollState()
  ScrollToTopOnReselect(scroll)

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      SettingsTopBar(title = stringResource(R.string.settings_title), onBack = onBack)

      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(scroll)
          .padding(horizontal = Dp.edge)
          // Clears the mini player too while a track is loaded, or the pill
          // sits on the version footer with no way to scroll it free.
          .padding(top = Dp.rhythm, bottom = SCROLL_BOTTOM_INSET + LocalMiniPlayerClearance.current),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        IdentityHeader(account, plan = PlanLabel.of(storeStatus, hasPremium))

        SettingsSection(title = stringResource(R.string.settings_section_preferences)) {
          SettingsRow(
            title = stringResource(R.string.settings_language),
            icon = DeepIcons.Globe,
            accessory = SettingsAccessory.Value(language.endonym),
            onClick = onOpenLanguage,
          )
          SettingsRow(
            title = stringResource(R.string.settings_daily_reminder),
            icon = ProfileIcons.Bell,
            // The time in the reading language's own clock — 24-hour in Thai,
            // am/pm in US English — while it is on.
            accessory = if (reminder.isEnabled) {
              SettingsAccessory.Value(AppFormat.time(reminder.hour, reminder.minute, locale))
            } else {
              SettingsAccessory.Chevron
            },
            onClick = onOpenReminder,
          )
        }

        MembershipSection(
          // Only once the store has said there is nothing — Unknown would put
          // "Upgrade" above a chip still reading "Checking…", and offer a
          // paying member what they already have.
          onUpgrade = onUpgrade.takeIf { storeStatus == SubscriptionState.None && !hasPremium },
          onManage = if (hasPremium) ::manageSubscription else null,
          restorePhase = restorePhase,
          onRestore = ::restorePurchases,
        )

        SettingsSection(title = stringResource(R.string.settings_section_account)) {
          SettingsRow(
            title = stringResource(R.string.settings_log_out),
            icon = ProfileIcons.LogOut,
            accessory = if (isLoggingOut) SettingsAccessory.Progress else SettingsAccessory.None,
            onClick = { if (!isLoggingOut) confirmingLogOut = true },
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

  // Logging out empties this phone's journal and listen queue, so practice
  // the server hasn't received yet would be lost — the member decides,
  // knowing that. A title alone, as iOS's alert has no message.
  if (confirmingUnsynced) {
    DeepDialog(
      title = stringResource(R.string.settings_unsynced_title),
      actions = listOf(
        DialogAction(stringResource(R.string.settings_log_out_stay)) { confirmingUnsynced = false },
        DialogAction(stringResource(R.string.settings_unsynced_log_out), destructive = true) {
          confirmingUnsynced = false
          logOutAnyway()
        },
      ),
      onDismissRequest = { confirmingUnsynced = false },
    ) {}
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
internal fun SettingsTopBar(title: String, onBack: () -> Unit) {
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
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
    )
  }
}

// MARK: - Membership

/**
 * The Membership card — iOS's `membershipSection`: the way in for the free
 * plan ([onUpgrade], when there is one), Manage subscription for members only
 * ([onManage]; there is nothing to manage on the free plan), and Restore
 * purchases for everyone, with its quiet line beneath when the store can't
 * be reached.
 */
@Composable
private fun MembershipSection(
  onUpgrade: (() -> Unit)?,
  onManage: (() -> Unit)?,
  restorePhase: RestorePhase,
  onRestore: () -> Unit,
) {
  val restoring = stringResource(R.string.settings_restoring)
  Column(verticalArrangement = Arrangement.spacedBy(MEMBERSHIP_NOTE_SPACING)) {
    SettingsSection(title = stringResource(R.string.settings_section_membership)) {
      if (onUpgrade != null) {
        SettingsRow(
          title = stringResource(R.string.settings_upgrade),
          icon = ProfileIcons.Sparkles,
          accessory = SettingsAccessory.Chevron,
          onClick = onUpgrade,
        )
      }
      if (onManage != null) {
        SettingsRow(
          title = stringResource(R.string.settings_manage_subscription),
          icon = ProfileIcons.CreditCard,
          accessory = SettingsAccessory.Chevron,
          onClick = onManage,
        )
      }
      SettingsRow(
        title = stringResource(R.string.settings_restore_purchases),
        icon = ProfileIcons.ArrowClockwise,
        accessory = when (restorePhase) {
          RestorePhase.Idle, RestorePhase.Failed -> SettingsAccessory.None
          RestorePhase.Working -> SettingsAccessory.Progress
          RestorePhase.Restored -> SettingsAccessory.Value(stringResource(R.string.settings_restored))
        },
        modifier = Modifier.semantics { if (restorePhase == RestorePhase.Working) stateDescription = restoring },
        onClick = onRestore,
      )
    }
    AnimatedVisibility(
      visible = restorePhase == RestorePhase.Failed,
      enter = fadeIn(settle()),
      exit = fadeOut(settle()),
      label = "restore-failed",
    ) {
      Text(
        text = stringResource(R.string.settings_restore_failed),
        style = DeepType.caption,
        color = Color.driftGrey,
        modifier = Modifier.padding(horizontal = MEMBERSHIP_NOTE_INSET),
      )
    }
  }
}

// MARK: - Identity

@Composable
private fun IdentityHeader(account: Account?, plan: PlanLabel) {
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

    PlanChip(plan, Modifier.padding(top = 4.dp))
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
 * The soft lavender lift under the avatar — `Modifier.dropShadow`, as in
 * `frostedCard`, because a platform elevation shadow reads as hard grey here.
 */
private fun Modifier.avatarGlow(): Modifier = dropShadow(
  shape = CircleShape,
  shadow = Shadow(
    radius = AVATAR_GLOW_RADIUS,
    color = Color.lavenderMist.copy(alpha = AVATAR_GLOW_ALPHA),
    offset = DpOffset(0.dp, AVATAR_GLOW_OFFSET_Y),
  ),
)

/**
 * The non-actionable membership status, worn as part of the identity — the
 * cards below stay purely actionable.
 */
@Composable
private fun PlanChip(plan: PlanLabel, modifier: Modifier = Modifier) {
  val label = stringResource(
    when (plan) {
      PlanLabel.PremiumYearly -> R.string.settings_plan_premium_yearly
      PlanLabel.PremiumMonthly -> R.string.settings_plan_premium_monthly
      PlanLabel.Premium -> R.string.settings_plan_premium
      PlanLabel.Free -> R.string.settings_free_plan
      PlanLabel.Checking -> R.string.settings_plan_checking
    },
  )
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
    Text(text = label, style = DeepType.micro, color = Color.driftGrey)
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
        reminder = DailyReminder(isEnabled = true, hour = 21, minute = 0),
        flushBeforeLogOut = { true },
        resetAccountState = {},
        onOpenLanguage = {},
        onOpenReminder = {},
        onBack = {},
      )
    }
  }
}

@Preview(showBackground = true, name = "Settings — DEEP Premium member")
@Composable
private fun SettingsScreenMemberPreview() {
  DeepTheme {
    CompositionLocalProvider(
      LocalPremiumAccess provides FakePremiumAccess(hasPremium = true),
      LocalSubscriptionStore provides PreviewSubscriptionStore(SubscriptionState.Subscribed(DeepProduct.YEARLY)),
    ) {
      Box(Modifier.fillMaxSize().background(Color.moonCream)) {
        SettingsScreen(
          accountStore = MockAccountStore.emailUser,
          onboardingStore = MockOnboardingProgressStore.fresh,
          language = AppLanguage.English,
          reminder = DailyReminder.initial,
          flushBeforeLogOut = { true },
          resetAccountState = {},
          onOpenLanguage = {},
          onOpenReminder = {},
          onBack = {},
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Settings — free plan, with the paywall's door")
@Composable
private fun SettingsScreenUpgradePreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      SettingsScreen(
        accountStore = MockAccountStore.emailUser,
        onboardingStore = MockOnboardingProgressStore.fresh,
        language = AppLanguage.English,
        reminder = DailyReminder.initial,
        flushBeforeLogOut = { true },
        resetAccountState = {},
        onOpenLanguage = {},
        onOpenReminder = {},
        onBack = {},
        onUpgrade = {},
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
        reminder = DailyReminder.initial,
        flushBeforeLogOut = { true },
        resetAccountState = {},
        onOpenLanguage = {},
        onOpenReminder = {},
        onBack = {},
      )
    }
  }
}
