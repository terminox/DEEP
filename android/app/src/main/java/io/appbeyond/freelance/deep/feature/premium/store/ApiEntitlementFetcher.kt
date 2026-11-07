package io.appbeyond.freelance.deep.feature.premium.store

import io.appbeyond.freelance.deep.feature.premium.model.ServerEntitlement
import io.appbeyond.freelance.deep.networking.AuthService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain

/**
 * [EntitlementFetching] over deep-api. Ported from `APIEntitlementFetcher` in
 * Deep/Deep/Features/Premium/Store/EntitlementFetching.swift.
 *
 * @param isSignedIn whether a session exists. Signed out, there is no one to
 *   ask about — and an unauthenticated `/me` would only 401.
 */
class ApiEntitlementFetcher(
  private val auth: AuthService,
  private val isSignedIn: () -> Boolean,
) : EntitlementFetching {

  override suspend fun currentEntitlement(): ServerEntitlement? {
    if (!isSignedIn()) return null
    return apiCall { auth.me() }.entitlement?.toDomain()
  }

  override suspend fun refreshEntitlement(): ServerEntitlement? {
    if (!isSignedIn()) return null
    return apiCall { auth.refreshEntitlement() }.entitlement.toDomain()
  }
}
