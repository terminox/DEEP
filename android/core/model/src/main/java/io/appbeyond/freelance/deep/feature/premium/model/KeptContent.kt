package io.appbeyond.freelance.deep.feature.premium.model

/**
 * Content kept after a fetch, stamped with who it was fetched for and the
 * DEEP Premium content epoch it was fetched under
 * (`PremiumAccess.contentEpoch`).
 *
 * The server's verdicts — and the audio it withholds — are baked into what it
 * sends, so content fetched under an older epoch may be wrong for the answer
 * the member has now. iOS can key a reload on the epoch changing because its
 * tabs stay alive; on Android a screen on a tab that isn't showing is
 * disposed, and one rebuilt after the epoch moved would take the new epoch
 * for the one it arrived on and never fetch again. So the data carries its
 * epoch instead, and whoever holds it compares: [isStale] against the
 * current epoch, whether or not anything was on screen when it moved.
 *
 * @property owner the DEEP user id it was fetched for; null when signed out.
 */
data class KeptContent<T>(
  val owner: String?,
  val epoch: Int,
  val value: T,
) {
  /** Whether this copy was fetched before the premium answer last moved. */
  fun isStale(currentEpoch: Int): Boolean = epoch < currentEpoch

  companion object {
    /** The copy fetched under the newest epoch, or null when there is none. */
    fun <T> freshest(vararg copies: KeptContent<T>?): KeptContent<T>? =
      copies.filterNotNull().maxByOrNull { it.epoch }
  }
}
