package io.appbeyond.freelance.deep.shared.components

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.unit.dp

/**
 * How much room the docked mini player takes above the tab bar, so a scrolling
 * screen can end its content clear of it.
 *
 * iOS never needed this: the mini player lives in the tab bar's bottom
 * accessory, which participates in the safe area, so content clears it
 * natively and `DeepSoundCoordinatorView` only adds `.rhythm` of breathing
 * room. Compose has no accessory slot on a custom bar, so the shell provides
 * the pill's height plus 8dp while a track is loaded, and `0.dp` otherwise.
 *
 * Screens *add* this to their own bottom content padding rather than replacing
 * it — the breathing room is theirs, the clearance is the shell's.
 */
val LocalMiniPlayerClearance = compositionLocalOf { 0.dp }
