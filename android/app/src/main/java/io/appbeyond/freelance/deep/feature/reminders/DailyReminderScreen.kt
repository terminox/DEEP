package io.appbeyond.freelance.deep.feature.reminders

import android.Manifest
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.profile.DeepDialog
import io.appbeyond.freelance.deep.feature.profile.DialogAction
import io.appbeyond.freelance.deep.feature.profile.ProfileIcons
import io.appbeyond.freelance.deep.feature.profile.SettingsSection
import io.appbeyond.freelance.deep.feature.profile.SettingsTimeRow
import io.appbeyond.freelance.deep.feature.profile.SettingsToggleRow
import io.appbeyond.freelance.deep.feature.profile.SettingsTopBar
import io.appbeyond.freelance.deep.feature.reminders.model.DailyReminder
import io.appbeyond.freelance.deep.feature.reminders.store.MockReminderScheduler
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderPermission
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderStore
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softLilac
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.ZoneId

/**
 * The daily reminder screen, pushed from Settings.
 *
 * Ported from Deep/Deep/Features/Reminders/Screens/DailyReminderView.swift.
 * This is the first system permission DEEP asks for, so the screen explains
 * itself before the switch is touched: a refusal can only be undone in system
 * settings, so it's worth one sentence to avoid earning one.
 *
 * `POST_NOTIFICATIONS` is asked at the moment the switch is turned on (API
 * 33+; below that there is nothing to ask). A refusal leaves the switch off
 * and names the way back — Android's own notification settings for DEEP —
 * rather than a switch that silently springs back. The system's answer is
 * re-read on every resume, since it can change in settings while DEEP is away.
 *
 * @param enable turns the reminder on through the store; handed the prompt.
 * @param setTime adopts a new clock face.
 * @param disable turns it off.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailyReminderScreen(
  store: ReminderStore,
  enable: suspend (prompt: suspend () -> Boolean) -> ReminderPermission,
  setTime: suspend (hour: Int, minute: Int) -> Unit,
  disable: suspend () -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val state by store.state.collectAsStateWithLifecycle()
  val reminder = state.reminder
  val scope = rememberCoroutineScope()
  val context = LocalContext.current
  val locale = rememberAppLocale()

  // The permission dialog answers through the activity; the store awaits it.
  var pendingAnswer by remember { mutableStateOf<CompletableDeferred<Boolean>?>(null) }
  val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
    pendingAnswer?.complete(granted)
    pendingAnswer = null
  }
  val currentLauncher by rememberUpdatedState(launcher)
  val prompt: suspend () -> Boolean = {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      val answer = CompletableDeferred<Boolean>()
      pendingAnswer = answer
      currentLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
      answer.await()
    } else {
      false
    }
  }

  LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
    scope.launch { store.refreshPermission() }
  }

  var pickingTime by remember { mutableStateOf(false) }

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      SettingsTopBar(title = stringResource(R.string.reminder_title), onBack = onBack)
      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(horizontal = Dp.edge)
          .padding(top = Dp.rhythm, bottom = 40.dp + LocalMiniPlayerClearance.current),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        Column(Modifier.padding(horizontal = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
          Text(stringResource(R.string.reminder_intro_title), style = DeepType.displayTitle, color = Color.deepPlum)
          Text(stringResource(R.string.reminder_intro_body), style = DeepType.body, color = Color.driftGrey)
        }

        SettingsSection {
          SettingsToggleRow(
            title = stringResource(R.string.reminder_toggle),
            checked = reminder.isEnabled,
            icon = ProfileIcons.Bell,
            onCheckedChange = { wantsOn ->
              scope.launch { if (wantsOn) enable(prompt) else disable() }
            },
          )
          AnimatedVisibility(
            visible = reminder.isEnabled,
            enter = fadeIn(settle()) + expandVertically(settle()),
            exit = fadeOut(settle()) + shrinkVertically(settle()),
          ) {
            SettingsTimeRow(
              title = stringResource(R.string.reminder_time),
              time = AppFormat.time(reminder.hour, reminder.minute, locale),
              icon = ProfileIcons.Clock,
              onClick = { pickingTime = true },
            )
          }
        }

        when {
          state.permission == ReminderPermission.Denied -> DeniedNote(
            onOpenSettings = {
              val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
              context.startActivity(intent)
            },
          )
          reminder.isEnabled -> Text(
            stringResource(R.string.reminder_skip_note),
            style = DeepType.caption,
            color = Color.driftGrey,
            modifier = Modifier.padding(horizontal = 8.dp),
          )
        }
      }
    }
  }

  if (pickingTime) {
    ReminderTimeDialog(
      reminder = reminder,
      is24Hour = AppFormat.uses24Hour(locale),
      onPick = { hour, minute ->
        pickingTime = false
        scope.launch { setTime(hour, minute) }
      },
      onDismiss = { pickingTime = false },
    )
  }
}

@Composable
private fun DeniedNote(onOpenSettings: () -> Unit) {
  Column(Modifier.padding(horizontal = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
    Text(stringResource(R.string.reminder_denied_note), style = DeepType.caption, color = Color.driftGrey)
    Text(
      text = stringResource(R.string.reminder_open_settings),
      style = DeepType.body,
      color = Color.deepPlum,
      modifier = Modifier.clickable(
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onOpenSettings,
      ),
    )
  }
}

/**
 * The clock face, in DEEP's dialog frame: Material's time picker, inked in the
 * palette, on the 12- or 24-hour dial the reading language uses (24 in Thai,
 * am/pm in US English) rather than the device's.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderTimeDialog(
  reminder: DailyReminder,
  is24Hour: Boolean,
  onPick: (hour: Int, minute: Int) -> Unit,
  onDismiss: () -> Unit,
) {
  val picker = rememberTimePickerState(initialHour = reminder.hour, initialMinute = reminder.minute, is24Hour = is24Hour)
  DeepDialog(
    title = stringResource(R.string.reminder_time_dialog_title),
    actions = listOf(
      DialogAction(stringResource(R.string.reminder_time_cancel), onClick = onDismiss),
      DialogAction(stringResource(R.string.reminder_time_set)) { onPick(picker.hour, picker.minute) },
    ),
    onDismissRequest = onDismiss,
  ) {
    TimePicker(
      state = picker,
      colors = TimePickerDefaults.colors(
        clockDialColor = Color.White.copy(alpha = 0.55f),
        clockDialSelectedContentColor = Color.White,
        clockDialUnselectedContentColor = Color.deepPlum,
        selectorColor = Color.lavenderMist,
        containerColor = Color.Transparent,
        periodSelectorBorderColor = Color.lavenderMist,
        periodSelectorSelectedContainerColor = Color.softLilac,
        periodSelectorUnselectedContainerColor = Color.Transparent,
        periodSelectorSelectedContentColor = Color.deepPlum,
        periodSelectorUnselectedContentColor = Color.driftGrey,
        timeSelectorSelectedContainerColor = Color.softLilac,
        timeSelectorUnselectedContainerColor = Color.White.copy(alpha = 0.55f),
        timeSelectorSelectedContentColor = Color.deepPlum,
        timeSelectorUnselectedContentColor = Color.deepPlum,
      ),
    )
  }
}

// MARK: - Previews

@Composable
private fun ReminderPreview(reminder: DailyReminder, permission: ReminderPermission) {
  val store = remember {
    ReminderStore(
      scheduler = MockReminderScheduler(currentPermission = permission),
      blob = InMemoryBlobStore(
        """{"isEnabled":${reminder.isEnabled},"hour":${reminder.hour},"minute":${reminder.minute}}""",
      ),
      clock = Clock.systemDefaultZone(),
      zone = { ZoneId.systemDefault() },
    )
  }
  LaunchedEffect(store) { store.refreshPermission() }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      DailyReminderScreen(
        store = store,
        enable = { ReminderPermission.Granted },
        setTime = { _, _ -> },
        disable = {},
        onBack = {},
      )
    }
  }
}

@Preview(showBackground = true, name = "Reminder — never asked")
@Composable
private fun ReminderOffPreview() = ReminderPreview(DailyReminder.initial, ReminderPermission.Unasked)

@Preview(showBackground = true, name = "Reminder — on")
@Composable
private fun ReminderOnPreview() =
  ReminderPreview(DailyReminder(isEnabled = true, hour = 21, minute = 0), ReminderPermission.Granted)

@Preview(showBackground = true, name = "Reminder — refused")
@Composable
private fun ReminderDeniedPreview() = ReminderPreview(DailyReminder.initial, ReminderPermission.Denied)
