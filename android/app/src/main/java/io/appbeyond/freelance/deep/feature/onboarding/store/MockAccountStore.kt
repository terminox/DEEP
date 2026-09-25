package io.appbeyond.freelance.deep.feature.onboarding.store

import io.appbeyond.freelance.deep.auth.Account
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * In-memory [AccountStore] for previews — no networking, no persistence. The
 * Android twin of `MockAccountStore.swift`. Sign-up/log-in fabricate a local
 * [Account] rather than validating anything; that validation is
 * [io.appbeyond.freelance.deep.onboarding.model.SignUpValidation]'s job and is
 * exercised on its own.
 */
class MockAccountStore(account: Account? = null) : AccountStore {

  private val _account = MutableStateFlow(account)
  override val account: StateFlow<Account?> = _account.asStateFlow()

  override suspend fun restore() {}

  override suspend fun signUp(displayName: String, email: String, password: String): Account {
    val fresh = Account(id = "mock", email = email, displayName = displayName)
    _account.value = fresh
    return fresh
  }

  override suspend fun logIn(email: String, password: String): Account {
    val fresh = Account(id = "mock", email = email, displayName = "Alex")
    _account.value = fresh
    return fresh
  }

  override suspend fun logOut() {
    _account.value = null
  }

  override suspend fun deleteAccount() {
    _account.value = null
  }

  companion object {
    val signedOut: MockAccountStore get() = MockAccountStore()

    val emailUser: MockAccountStore
      get() = MockAccountStore(Account(id = "mock-alex", email = "alex@deep.app", displayName = "Alex"))
  }
}
