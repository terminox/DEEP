package io.appbeyond.freelance.deep.feature.premium.model

/**
 * Whether an answer from the purchasing store speaks for the member DEEP
 * expects it to. The store (RevenueCat) is told who the member is on every
 * sign-in and sign-out, but its answers arrive asynchronously — a customer
 * info fetched for the last member can land after the next one signed in, or
 * an anonymous one after a sign-in. Adopting either would show one person
 * another's membership.
 */
object StoreIdentity {

  /** How RevenueCat spells an anonymous customer's id. */
  const val ANONYMOUS_PREFIX = "\$RCAnonymousID:"

  /**
   * @param expectedUserId the DEEP user id the store should speak for; null
   *   while signed out.
   * @param storeUserId whom the store is speaking for right now.
   * @param originalUserId the answer's own original app user id. A real
   *   (non-anonymous) one that isn't the expected member is someone else's
   *   answer outright. An anonymous one can't be told apart — a member's
   *   first customer may have been aliased from the install's anonymous one
   *   — so it rests on whom the store is speaking for.
   */
  fun answerFits(expectedUserId: String?, storeUserId: String, originalUserId: String): Boolean {
    val storeAnonymous = isAnonymous(storeUserId)
    if (expectedUserId == null) return storeAnonymous && isAnonymous(originalUserId)
    if (storeUserId != expectedUserId) return false
    return isAnonymous(originalUserId) || originalUserId == expectedUserId
  }

  fun isAnonymous(userId: String): Boolean = userId.startsWith(ANONYMOUS_PREFIX)
}
