package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/**
 * Each time the member re-taps the tab this screen sits in while it is the
 * front-most screen there. `MainShellCoordinator` hands every screen on every
 * stack only its own reselections; outside the shell (previews) nothing ever
 * arrives.
 *
 * The shell's half of iOS's `MainTabController.scrollSelectedTabToTop`, which
 * finds the front-most vertical scroll view by walking the view hierarchy.
 * Compose has no hierarchy to walk, so the screen says which scroll is "the
 * screen" by passing it to [ScrollToTopOnReselect].
 */
val LocalTabReselection = staticCompositionLocalOf<Flow<Unit>> { emptyFlow() }

/**
 * Scrolls [state] back to the top whenever this screen's tab is re-tapped —
 * the one line a scrolling tab screen adds. A re-tap never pops the stack.
 */
@Composable
fun ScrollToTopOnReselect(state: LazyListState) {
  val reselections = LocalTabReselection.current
  LaunchedEffect(reselections, state) {
    reselections.collect { state.animateScrollToItem(0) }
  }
}

/** [ScrollToTopOnReselect] for a plain `verticalScroll` column. */
@Composable
fun ScrollToTopOnReselect(state: ScrollState) {
  val reselections = LocalTabReselection.current
  LaunchedEffect(reselections, state) {
    reselections.collect { state.animateScrollTo(0) }
  }
}

@Preview(showBackground = true)
@Composable
private fun ScrollToTopOnReselectPreview() {
  val listState = rememberLazyListState()
  ScrollToTopOnReselect(listState)
  DeepTheme {
    Column(Modifier.fillMaxSize()) {
      LazyColumn(state = listState) {
        items(PREVIEW_ROWS) { Text("Row ${it + 1}", style = DeepType.body) }
      }
    }
  }
}

private const val PREVIEW_ROWS = 40
