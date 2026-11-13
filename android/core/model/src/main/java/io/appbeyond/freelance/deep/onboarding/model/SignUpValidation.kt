package io.appbeyond.freelance.deep.onboarding.model

/** Ported from `Account.swift`'s `AccountError` cases. */
enum class SignUpProblem { MissingName, MalformedEmail, ShortPassword }

object SignUpValidation {
  const val MIN_PASSWORD_LENGTH = 8

  /** deep-api refuses a longer display name, so the field stops here. */
  const val MAX_NAME_LENGTH = 40

  /** [name] cut to [MAX_NAME_LENGTH] UTF-16 units, the server's measure, never splitting a surrogate pair. */
  fun capName(name: String): String {
    if (name.length <= MAX_NAME_LENGTH) return name
    val cut = name.take(MAX_NAME_LENGTH)
    return if (cut.last().isHighSurrogate()) cut.dropLast(1) else cut
  }

  /** Button enabled: trimmed name, trimmed email and password all non-empty (and not submitting — the caller's job). */
  fun canSubmit(name: String, email: String, password: String): Boolean =
    name.trim().isNotEmpty() && email.trim().isNotEmpty() && password.isNotEmpty()

  /**
   * First problem in order name → email (must contain "@" and ".") → password (< 8).
   * Null when valid. Name and email trim the way [canSubmit] does; the password
   * never trims — spaces are real characters to deep-api, as they are on iOS.
   */
  fun problem(name: String, email: String, password: String): SignUpProblem? = when {
    name.trim().isEmpty() -> SignUpProblem.MissingName
    !looksLikeEmail(email.trim()) -> SignUpProblem.MalformedEmail
    password.length < MIN_PASSWORD_LENGTH -> SignUpProblem.ShortPassword
    else -> null
  }

  /** The email field's check mark: contains "@" and ".". */
  fun looksLikeEmail(email: String): Boolean = email.contains("@") && email.contains(".")

  /** Login button: trimmed email and password non-empty. */
  fun canLogIn(email: String, password: String): Boolean =
    email.trim().isNotEmpty() && password.isNotEmpty()
}
