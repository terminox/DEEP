package io.appbeyond.freelance.deep.onboarding.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Ported from Account.swift's `AccountError` validation, as used by SignUpView / LogInView. */
class SignUpValidationTest {

  // MARK: - canSubmit

  @Test
  @DisplayName("canSubmit is true only once name, email and password are all non-empty once trimmed")
  fun canSubmit() {
    assertTrue(SignUpValidation.canSubmit("Mali", "mali@example.com", "password"))
    assertFalse(SignUpValidation.canSubmit("", "mali@example.com", "password"))
    assertFalse(SignUpValidation.canSubmit("Mali", "", "password"))
    assertFalse(SignUpValidation.canSubmit("Mali", "mali@example.com", ""))
    assertFalse(SignUpValidation.canSubmit("   ", "mali@example.com", "password"), "whitespace-only name is empty")
  }

  // MARK: - problem ordering

  @Test
  @DisplayName("problem reports MissingName first, ahead of a malformed email or short password")
  fun problemMissingNameFirst() {
    assertEquals(SignUpProblem.MissingName, SignUpValidation.problem("", "not-an-email", "short"))
    assertEquals(SignUpProblem.MissingName, SignUpValidation.problem("  ", "mali@example.com", "password"))
  }

  @Test
  @DisplayName("problem reports MalformedEmail once the name is present")
  fun problemMalformedEmailNext() {
    assertEquals(SignUpProblem.MalformedEmail, SignUpValidation.problem("Mali", "not-an-email", "short"))
    assertEquals(SignUpProblem.MalformedEmail, SignUpValidation.problem("Mali", "malformed", "password"))
  }

  @Test
  @DisplayName("problem reports ShortPassword last, once the name and email are valid")
  fun problemShortPasswordLast() {
    assertEquals(SignUpProblem.ShortPassword, SignUpValidation.problem("Mali", "mali@example.com", "short"))
  }

  @Test
  @DisplayName("problem is null once name, email and password are all valid")
  fun problemNullWhenValid() {
    assertNull(SignUpValidation.problem("Mali", "mali@example.com", "password"))
  }

  @Test
  @DisplayName("problem trims the name the same way canSubmit does")
  fun problemTrimsName() {
    assertNull(SignUpValidation.problem("  Mali  ", "mali@example.com", "password"))
  }

  @Test
  @DisplayName("exactly 8 characters is a valid password; 7 is short")
  fun passwordLengthBoundary() {
    assertNull(SignUpValidation.problem("Mali", "mali@example.com", "12345678"))
    assertEquals(SignUpProblem.ShortPassword, SignUpValidation.problem("Mali", "mali@example.com", "1234567"))
  }

  // MARK: - looksLikeEmail

  @Test
  @DisplayName("looksLikeEmail requires both an @ and a .")
  fun looksLikeEmail() {
    assertTrue(SignUpValidation.looksLikeEmail("mali@example.com"))
    assertFalse(SignUpValidation.looksLikeEmail("mali@example"), "missing the dot")
    assertFalse(SignUpValidation.looksLikeEmail("mali.example.com"), "missing the @")
    assertFalse(SignUpValidation.looksLikeEmail(""))
  }

  // MARK: - canLogIn

  @Test
  @DisplayName("canLogIn requires a trimmed, non-empty email and password")
  fun canLogIn() {
    assertTrue(SignUpValidation.canLogIn("mali@example.com", "password"))
    assertFalse(SignUpValidation.canLogIn("", "password"))
    assertFalse(SignUpValidation.canLogIn("mali@example.com", ""))
    assertFalse(SignUpValidation.canLogIn("   ", "password"))
  }

  @Test
  @DisplayName("the password is never trimmed: surrounding spaces count toward its length")
  fun passwordIsNotTrimmed() {
    assertNull(SignUpValidation.problem("Mali", "mali@example.com", "  pass  "))
    assertTrue(SignUpValidation.canLogIn("mali@example.com", " "))
  }
}
