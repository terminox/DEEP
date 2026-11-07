package io.appbeyond.freelance.deep.shared.components

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.config.AppConfig
import io.appbeyond.freelance.deep.config.LegalLinks
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.rhythm

/**
 * The sentences that carry the legal links — iOS's `LegalCopy`.
 *
 * They live here rather than inside any one feature because onboarding and
 * the paywall must link the same two documents ([AppConfig.legal]). Terms and
 * Privacy are [LinkAnnotation.Url]s, which open through `LocalUriHandler` —
 * the browser, as iOS's Markdown links open Safari.
 */
object LegalText {

  /** Onboarding's line, where following through *is* the agreement. */
  @Composable
  fun agreement(links: LegalLinks = AppConfig.legal): AnnotatedString = sentence(R.string.onboarding_legal, links)

  /** The paywall's line, which invites rather than binds. */
  @Composable
  fun invitation(links: LegalLinks = AppConfig.legal): AnnotatedString = sentence(R.string.premium_legal, links)

  /**
   * [template] with `%1$s` as the Terms link and `%2$s` as the Privacy Policy
   * link, walked placeholder by placeholder, so a translation is free to put
   * the two links in whichever order its grammar wants. A translation that
   * drops a placeholder loses that link, never the paragraph.
   */
  @Composable
  private fun sentence(@StringRes template: Int, links: LegalLinks): AnnotatedString {
    val text = stringResource(template)
    val terms = stringResource(R.string.onboarding_terms)
    val privacy = stringResource(R.string.onboarding_privacy)
    val linkStyles = TextLinkStyles(SpanStyle(color = Color.deepPlum, textDecoration = TextDecoration.Underline))
    val placeholders = listOf("%1\$s" to (terms to links.terms), "%2\$s" to (privacy to links.privacy))

    return buildAnnotatedString {
      var rest = text
      while (true) {
        val next = placeholders
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
}

@Preview(showBackground = true, name = "Legal text")
@Composable
private fun LegalTextPreview() {
  Box(Modifier.fillMaxSize().padding(Dp.edge)) {
    Column(verticalArrangement = Arrangement.spacedBy(Dp.rhythm)) {
      Text(LegalText.agreement(), style = DeepType.micro, color = Color.driftGrey)
      Text(LegalText.invitation(), style = DeepType.micro, color = Color.driftGrey)
    }
  }
}
