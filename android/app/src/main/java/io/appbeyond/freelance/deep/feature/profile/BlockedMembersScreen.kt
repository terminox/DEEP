package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.components.PeaceMessageAvatar
import io.appbeyond.freelance.deep.feature.globalpause.components.peaceTint
import io.appbeyond.freelance.deep.feature.globalpause.model.BlockedMember
import io.appbeyond.freelance.deep.feature.globalpause.store.BlockedMembersList
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import java.time.Instant
import kotlinx.coroutines.launch

/**
 * Settings → Blocked members: everyone the member has blocked from a peace
 * message, each with Unblock. Pushed from Settings like the language picker,
 * in the same grammar — one frosted card of rows, a quiet footnote under it.
 *
 * Unblock takes effect at the tap; a refusal puts the row back and says so.
 * Nothing confirms an unblock: it is the gentle direction, and blocking again
 * is one menu away.
 *
 * Ported in step with iOS's `BlockedMembersView`.
 */
@Composable
fun BlockedMembersScreen(
  list: BlockedMembersList,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val state by list.state.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()
  LaunchedEffect(list) { list.load() }

  BlockedMembersContent(
    state = state,
    onUnblock = { member -> scope.launch { list.unblock(member) } },
    onRetry = { scope.launch { list.load() } },
    onBack = onBack,
    modifier = modifier,
  )
}

/** The screen for a given state — stateless, so previews show each one. */
@Composable
private fun BlockedMembersContent(
  state: BlockedMembersList.State,
  onUnblock: (BlockedMember) -> Unit,
  onRetry: () -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val scroll = rememberScrollState()
  ScrollToTopOnReselect(scroll)

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      SettingsTopBar(title = stringResource(R.string.blocked_title), onBack = onBack)
      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(scroll)
          .padding(horizontal = Dp.edge)
          .padding(top = Dp.rhythm, bottom = 40.dp + LocalMiniPlayerClearance.current),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        when {
          state.phase == BlockedMembersList.Phase.Loading -> Box(
            Modifier.fillMaxWidth().padding(vertical = STATE_PADDING_VERTICAL),
            contentAlignment = Alignment.Center,
          ) {
            CircularProgressIndicator(color = Color.driftGrey, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
          }

          state.phase == BlockedMembersList.Phase.Failed -> Failure(onRetry)

          state.isEmpty -> SettingsSection {
            Text(
              text = stringResource(R.string.blocked_empty),
              style = DeepType.body,
              color = Color.driftGrey,
              textAlign = TextAlign.Center,
              modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = EMPTY_PADDING_VERTICAL),
            )
          }

          else -> {
            SettingsSection {
              state.members.forEach { member ->
                BlockedMemberRow(member, onUnblock = { onUnblock(member) })
              }
            }
            AnimatedVisibility(visible = state.unblockFailed, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
              Text(
                text = stringResource(R.string.safety_failed),
                style = DeepType.caption,
                color = Color.deepPlum,
                modifier = Modifier.padding(horizontal = 8.dp),
              )
            }
            Text(
              text = stringResource(R.string.blocked_footnote),
              style = DeepType.caption,
              color = Color.driftGrey,
              modifier = Modifier.padding(horizontal = 8.dp),
            )
          }
        }
      }
    }
  }
}

/** One blocked member: who, and the way back. */
@Composable
private fun BlockedMemberRow(member: BlockedMember, onUnblock: () -> Unit) {
  val unblockLabel = stringResource(R.string.blocked_unblock_a11y, member.displayName)
  Row(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = 16.dp, vertical = 12.dp),
    horizontalArrangement = Arrangement.spacedBy(12.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    PeaceMessageAvatar(tint = peaceTint(member.id), initial = member.displayName.firstOrNull()?.toString() ?: "?")
    // Weighted, not beside a Spacer: a Spacer bids against the name.
    Text(
      text = member.displayName,
      style = DeepType.body,
      color = Color.deepPlum,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      modifier = Modifier.weight(1f),
    )
    Text(
      text = stringResource(R.string.blocked_unblock),
      style = DeepType.bodyMedium,
      color = Color.deepPlum,
      modifier = Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onClick = onUnblock,
        )
        .semantics { contentDescription = unblockLabel }
        .padding(horizontal = 16.dp, vertical = 8.dp),
    )
  }
}

/** Couldn't load: says so, with the house "Try again" chip. */
@Composable
private fun Failure(onRetry: () -> Unit) {
  Column(
    Modifier.fillMaxWidth().padding(vertical = STATE_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    Text(
      text = stringResource(R.string.blocked_load_failed),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Text(
      text = stringResource(R.string.blocked_retry),
      style = DeepType.bodyMedium,
      color = Color.deepPlum,
      modifier = Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onClick = onRetry,
        )
        .padding(horizontal = 22.dp, vertical = 12.dp),
    )
  }
}

private val STATE_PADDING_VERTICAL = 48.dp
private val EMPTY_PADDING_VERTICAL = 28.dp

// MARK: - Previews

private val previewMembers = listOf(
  BlockedMember("b1", "Haruki", Instant.parse("2026-11-12T10:00:00Z")),
  BlockedMember("b2", "Camille", Instant.parse("2026-11-10T10:00:00Z")),
)

@Composable
private fun BlockedPreview(state: BlockedMembersList.State) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      BlockedMembersContent(state = state, onUnblock = {}, onRetry = {}, onBack = {})
    }
  }
}

@Preview(showBackground = true, name = "Blocked members")
@Composable
private fun BlockedMembersPreview() =
  BlockedPreview(BlockedMembersList.State(phase = BlockedMembersList.Phase.Loaded, members = previewMembers))

@Preview(showBackground = true, name = "Blocked members — empty")
@Composable
private fun BlockedMembersEmptyPreview() =
  BlockedPreview(BlockedMembersList.State(phase = BlockedMembersList.Phase.Loaded))

@Preview(showBackground = true, name = "Blocked members — couldn't load, Thai", locale = "th")
@Composable
private fun BlockedMembersFailedPreview() =
  BlockedPreview(BlockedMembersList.State(phase = BlockedMembersList.Phase.Failed))
