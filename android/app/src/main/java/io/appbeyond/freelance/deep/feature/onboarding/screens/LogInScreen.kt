package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.AuthField
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingGlyphs
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProfile
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.onboarding.model.SignUpValidation
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private val HEADER_SPACING = 6.dp
private val HEADER_TOP = 8.dp
private val FIELD_SPACING = 14.dp

/**
 * Returning-member log-in, reachable from the welcome screen and the account
 * gateway. On success it reads the member's onboarding profile from the server
 * and hydrates the local store: a completed profile opens the root gate straight
 * into the app (the root flips to Main on its own — nothing to route here);
 * otherwise the flow resumes at the first question, and the navigator replaces
 * the stack so back from there returns to welcome, not this form.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/LogInView.swift, with two
 * changes:
 *  - When the profile can't be read, the local answers are re-hydrated as
 *    not-complete (iOS leaves the store untouched). Resuming at the quiz is the
 *    safe path either way; this also clears any stale completion flag.
 *  - That stale flag is cleared *before* the request too, for the reason
 *    [SignUpScreen] documents: the account publishes before `logIn` returns, and
 *    a stale `completed = true` would flip the root to Main on that emission.
 *
 * A wrong password arrives as `DeepApiException.Http` carrying the server's
 * "Incorrect email or password", shown verbatim.
 *
 * While the request is in flight, back is held and the coordinator's chrome
 * hidden — see [AuthRequestGuard].
 */
@Composable
fun LogInScreen(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  remote: OnboardingRemote,
  onAdvance: (OnboardingRoute) -> Unit,
  modifier: Modifier = Modifier,
  onSubmittingChange: (Boolean) -> Unit = {},
) {
  var email by rememberSaveable { mutableStateOf("") }
  var password by remember { mutableStateOf("") }
  var errorMessage by remember { mutableStateOf<String?>(null) }
  var isSubmitting by remember { mutableStateOf(false) }

  val scope = rememberCoroutineScope()
  val focusManager = LocalFocusManager.current
  val breatheLine = stringResource(R.string.onboarding_log_in_breathe)
  val fallback = stringResource(R.string.onboarding_log_in_failed)

  val canSubmit = SignUpValidation.canLogIn(email, password) && !isSubmitting

  fun submit() {
    if (!canSubmit) return
    focusManager.clearFocus()
    isSubmitting = true
    errorMessage = null
    scope.launch {
      try {
        val profile: OnboardingProfile? = heldForBreatheFloor {
          val local = onboardingStore.state.value
          if (local.hasCompletedOnboarding) {
            onboardingStore.hydrate(local.quizAnswers, local.mindTree, completed = false)
          }
          accountStore.logIn(email = email.trim(), password = password)
          try {
            remote.fetchProfile()
          } catch (e: CancellationException) {
            throw e
          } catch (e: Exception) {
            null
          }
        }

        if (profile?.completed == true) {
          // The root gate opens on this write. The beat stays up so the
          // hand-off crossfades breath → app rather than breath → form → app.
          onboardingStore.hydrate(profile.quizAnswers, profile.mindTree, completed = true)
          return@launch
        }

        val answers = profile?.quizAnswers ?: onboardingStore.state.value.quizAnswers
        val tree = if (profile != null) profile.mindTree else onboardingStore.state.value.mindTree
        onboardingStore.hydrate(answers, tree, completed = false)
        onAdvance(OnboardingRoute.Quiz(0))
      } catch (e: CancellationException) {
        throw e
      } catch (e: Exception) {
        errorMessage = e.displayMessage(fallback)
      }
      isSubmitting = false
    }
  }

  AuthRequestGuard(submitting = isSubmitting, onSubmittingChange = onSubmittingChange)

  Box(modifier.fillMaxSize()) {
    Column(
      modifier = Modifier
        .fillMaxSize()
        .safeDrawingPadding()
        .padding(horizontal = Dp.edge)
        .padding(bottom = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      Column(
        modifier = Modifier
          .weight(1f)
          .verticalScroll(rememberScrollState())
          .onboardingContentDrift(),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        Column(
          modifier = Modifier.padding(top = HEADER_TOP),
          verticalArrangement = Arrangement.spacedBy(HEADER_SPACING),
        ) {
          Text(
            text = stringResource(R.string.onboarding_log_in_title),
            style = DeepType.displayTitle,
            color = Color.deepPlum,
          )
          Text(
            text = stringResource(R.string.onboarding_log_in_subtitle),
            style = DeepType.caption,
            color = Color.driftGrey,
          )
        }

        Column(verticalArrangement = Arrangement.spacedBy(FIELD_SPACING)) {
          AuthField(
            value = email,
            onValueChange = { email = it },
            placeholder = stringResource(R.string.onboarding_field_email),
            icon = OnboardingGlyphs.Envelope,
            keyboardType = KeyboardType.Email,
            contentType = ContentType.EmailAddress,
          )
          AuthField(
            value = password,
            onValueChange = { password = it },
            placeholder = stringResource(R.string.onboarding_field_password),
            icon = OnboardingGlyphs.Lock,
            isSecure = true,
            imeAction = ImeAction.Go,
            onImeAction = ::submit,
            contentType = ContentType.Password,
          )
        }

        AnimatedVisibility(visible = errorMessage != null, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
          Text(
            text = errorMessage.orEmpty(),
            style = DeepType.caption,
            color = Color.deepPlum,
            modifier = Modifier.fillMaxWidth(),
          )
        }
      }

      OnboardingPrimaryButton(
        title = stringResource(R.string.onboarding_log_in),
        enabled = canSubmit,
        onClick = ::submit,
      )
    }

    AuthBreatheOverlay(visible = isSubmitting, line = breatheLine)
  }
}

@Preview(showBackground = true, name = "Log in")
@Composable
private fun LogInScreenPreview() {
  OnboardingPreviewBackdrop {
    LogInScreen(
      accountStore = MockAccountStore.signedOut,
      onboardingStore = MockOnboardingProgressStore.fresh,
      remote = MockOnboardingRemote(),
      onAdvance = {},
    )
  }
}
