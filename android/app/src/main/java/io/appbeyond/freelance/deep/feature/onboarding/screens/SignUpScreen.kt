package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.onboarding.components.AuthField
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingGlyphs
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.SelectionMark
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.onboarding.model.SignUpProblem
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
private val RULE_SPACING = 8.dp
private val RULE_INSET = 18.dp
private const val RULE_RING_ALPHA = 1f

/** Sized to the caption beside it, as iOS sizes the symbol with `.font(DeepType.caption)`. */
private val RULE_MARK_SIZE = 14.dp

/**
 * The create-account form, after the gateway. On success the flow moves to
 * [CraftingSpaceScreen], whose loader syncs the gathered answers to the server.
 * A gentle invitation, never a wall.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/SignUpView.swift, with
 * validation from [SignUpValidation] (so the email check mark and the submit
 * check can never disagree). One ordering change: iOS re-asserts
 * `completed = false` *after* the account lands, to stop a stale completion flag
 * left by a previous account opening the root gate. Here the account flow
 * publishes before `signUp` returns, and the root recomposes on that emission —
 * so a stale flag would flip the root to Main (unmounting this screen and
 * cancelling the sync) before a post-hoc reset could run. The reset therefore
 * happens before the request. It is harmless if the request fails: the flag
 * only opens the gate for a signed-in member.
 *
 * While the request is in flight, back is held and the coordinator's chrome
 * hidden — see [AuthRequestGuard].
 */
@Composable
fun SignUpScreen(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  onAdvance: (OnboardingRoute) -> Unit,
  modifier: Modifier = Modifier,
  onSubmittingChange: (Boolean) -> Unit = {},
) {
  var name by rememberSaveable { mutableStateOf("") }
  var email by rememberSaveable { mutableStateOf("") }
  var password by remember { mutableStateOf("") }
  var errorMessage by remember { mutableStateOf<String?>(null) }
  var isSubmitting by remember { mutableStateOf(false) }

  val scope = rememberCoroutineScope()
  val focusManager = LocalFocusManager.current
  val breatheLine = stringResource(R.string.onboarding_sign_up_breathe)
  val fallback = stringResource(R.string.onboarding_sign_up_failed)
  val problemText = mapOf(
    SignUpProblem.MissingName to stringResource(R.string.onboarding_problem_missing_name),
    SignUpProblem.MalformedEmail to stringResource(R.string.onboarding_problem_malformed_email),
    SignUpProblem.ShortPassword to stringResource(R.string.onboarding_problem_short_password),
  )

  val canSubmit = SignUpValidation.canSubmit(name, email, password) && !isSubmitting
  val passwordLongEnough = password.length >= SignUpValidation.MIN_PASSWORD_LENGTH

  fun submit() {
    if (!canSubmit) return
    SignUpValidation.problem(name, email, password)?.let { problem ->
      errorMessage = problemText.getValue(problem)
      return
    }

    focusManager.clearFocus()
    isSubmitting = true
    errorMessage = null
    scope.launch {
      try {
        heldForBreatheFloor {
          // Re-assert the gathered answers as not-yet-complete *before* the
          // account publishes — see the class doc.
          val gathered = onboardingStore.state.value
          onboardingStore.hydrate(gathered.quizAnswers, gathered.mindTree, completed = false)
          accountStore.signUp(displayName = name.trim(), email = email.trim(), password = password)
        }
        onAdvance(OnboardingRoute.CraftingSpace)
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
            text = stringResource(R.string.onboarding_sign_up_title),
            style = DeepType.displayTitle,
            color = Color.deepPlum,
          )
          Text(
            text = stringResource(R.string.onboarding_sign_up_subtitle),
            style = DeepType.caption,
            color = Color.driftGrey,
          )
        }

        Column(verticalArrangement = Arrangement.spacedBy(FIELD_SPACING)) {
          AuthField(
            value = name,
            onValueChange = { name = it },
            placeholder = stringResource(R.string.onboarding_field_name),
            icon = DeepIcons.Person,
            capitalization = KeyboardCapitalization.Words,
            contentType = ContentType.PersonFullName,
          )
          AuthField(
            value = email,
            onValueChange = { email = it },
            placeholder = stringResource(R.string.onboarding_field_email),
            icon = OnboardingGlyphs.Envelope,
            isValid = if (SignUpValidation.looksLikeEmail(email.trim())) true else null,
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
            contentType = ContentType.NewPassword,
          )

          Row(
            modifier = Modifier
              .fillMaxWidth()
              .padding(start = RULE_INSET),
            horizontalArrangement = Arrangement.spacedBy(RULE_SPACING),
            verticalAlignment = Alignment.CenterVertically,
          ) {
            SelectionMark(isSelected = passwordLongEnough, hollowAlpha = RULE_RING_ALPHA, size = RULE_MARK_SIZE)
            Text(
              text = stringResource(R.string.onboarding_password_rule),
              style = DeepType.caption,
              color = Color.driftGrey,
            )
          }
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
        title = stringResource(R.string.onboarding_create_account),
        enabled = canSubmit,
        onClick = ::submit,
      )
    }

    AuthBreatheOverlay(visible = isSubmitting, line = breatheLine)
  }
}

@Preview(showBackground = true, name = "Sign up")
@Composable
private fun SignUpScreenPreview() {
  OnboardingPreviewBackdrop {
    SignUpScreen(
      accountStore = MockAccountStore.signedOut,
      onboardingStore = MockOnboardingProgressStore.midQuiz,
      onAdvance = {},
    )
  }
}
