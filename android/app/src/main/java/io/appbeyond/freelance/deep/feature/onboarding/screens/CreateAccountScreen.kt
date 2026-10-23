package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.DeepLogoMark
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingGlyphs
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.onboardingContentDrift
import io.appbeyond.freelance.deep.onboarding.model.OnboardingRoute
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

private val MARK_SIZE = 80.dp
private val ACTION_SPACING = 16.dp

private const val TERMS_URL = "https://deep.app/terms"
private const val PRIVACY_URL = "https://deep.app/privacy"

/**
 * The account gateway after the Mind Tree — the invitation to keep what the
 * flow has gathered. Email is the one sign-up method today (more slot into the
 * footer later), plus the log-in escape for returning members. The form itself
 * is [SignUpScreen].
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/CreateAccountView.swift.
 * Terms and Privacy are [LinkAnnotation.Url]s, which open through
 * `LocalUriHandler` — the browser, as iOS's Markdown links open Safari.
 */
@Composable
fun CreateAccountScreen(
  onAdvance: (OnboardingRoute) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier = modifier
      .fillMaxSize()
      .safeDrawingPadding()
      .padding(horizontal = Dp.edge)
      .padding(vertical = Dp.rhythm),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    DeepLogoMark(size = MARK_SIZE, tint = Color.moonCream, isGlowing = true)

    OnboardingLogoText()

    Spacer(Modifier.weight(1f))

    Text(
      text = stringResource(R.string.onboarding_create_account_title),
      style = DeepType.displayTitle,
      color = Color.deepPlum,
      textAlign = TextAlign.Center,
      modifier = Modifier.onboardingContentDrift(),
    )

    Column(
      modifier = Modifier.fillMaxWidth(),
      verticalArrangement = Arrangement.spacedBy(ACTION_SPACING),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      OnboardingPrimaryButton(
        title = stringResource(R.string.onboarding_continue_with_email),
        icon = OnboardingGlyphs.Envelope,
        onClick = { onAdvance(OnboardingRoute.SignUp) },
      )

      HaveAccountLink(onClick = { onAdvance(OnboardingRoute.LogIn) })

      Text(
        text = legalText(),
        style = DeepType.micro,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
      )
    }
  }
}

/** "By continuing, you agree to our Terms and Privacy Policy." with both names as links. */
@Composable
private fun legalText(): AnnotatedString {
  val template = stringResource(R.string.onboarding_legal)
  val terms = stringResource(R.string.onboarding_terms)
  val privacy = stringResource(R.string.onboarding_privacy)
  val linkStyles = TextLinkStyles(SpanStyle(color = Color.deepPlum, textDecoration = TextDecoration.Underline))
  val links = listOf("%1\$s" to (terms to TERMS_URL), "%2\$s" to (privacy to PRIVACY_URL))

  return buildAnnotatedString {
    // Walk the template placeholder by placeholder, so a translation is free
    // to put the two links in whichever order its grammar wants.
    var rest = template
    while (true) {
      val next = links
        .map { (token, link) -> Triple(rest.indexOf(token), token, link) }
        .filter { it.first >= 0 }
        .minByOrNull { it.first }
        ?: break
      val (at, token, link) = next
      append(rest.substring(0, at))
      withLink(LinkAnnotation.Url(link.second, linkStyles)) { append(link.first) }
      rest = rest.substring(at + token.length)
    }
    append(rest)
  }
}

@Preview(showBackground = true, name = "Create account — gateway")
@Composable
private fun CreateAccountScreenPreview() {
  OnboardingPreviewBackdrop {
    CreateAccountScreen(onAdvance = {})
  }
}
