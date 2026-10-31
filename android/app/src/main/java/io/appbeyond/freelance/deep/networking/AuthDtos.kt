package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.feature.premium.model.ServerEntitlement
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeParseException

/*
 * Wire shapes for deep-api's auth routes, ported from the `UserDTO` /
 * `AuthResponseDTO` family in `DTOs.swift`. `auth/signup`, `auth/login` and
 * `GET /me` all nest the member under a `user` key; `POST /auth/logout` and
 * `DELETE /me` answer with the same bare `{ ok: true }` shape.
 */

@Serializable
data class SignUpRequestDto(
  val email: String,
  val password: String,
  val displayName: String,
)

@Serializable
data class LogInRequestDto(
  val email: String,
  val password: String,
)

/**
 * The member as every auth route sends it. [role] and [createdAt] ride along
 * on the wire but map to nothing in [Account] yet — that domain type only
 * needs what the UI shows today.
 */
@Serializable
data class UserDto(
  val id: String,
  val email: String,
  val displayName: String,
  val role: String = "",
  val createdAt: String = "",
)

/**
 * `POST /auth/signup` and `POST /auth/login`. [entitlement] is the DEEP
 * Premium answer sent beside `user`; null from an older server.
 */
@Serializable
data class AuthResponseDto(
  val user: UserDto,
  val accessToken: String,
  val refreshToken: String,
  val expiresIn: Int = 0,
  val entitlement: EntitlementDto? = null,
)

/** `GET /me`. [entitlement] as on [AuthResponseDto]. */
@Serializable
data class MeResponseDto(
  val user: UserDto,
  val entitlement: EntitlementDto? = null,
)

/**
 * The server's DEEP Premium answer for the caller, as
 * `serializeEntitlement` (deep-api `lib/entitlement.ts`) writes it.
 * Everything past [active] is defaulted, so a leaner server still decodes.
 * Ported from `EntitlementDTO` in `DTOs.swift`.
 *
 * @property expiresAt ISO 8601; null for a grant that never expires.
 * @property periodType NORMAL | TRIAL | INTRO.
 * @property store APP_STORE | PLAY_STORE | PROMOTIONAL …, as RevenueCat names it.
 */
@Serializable
data class EntitlementDto(
  val active: Boolean,
  val productId: String? = null,
  val expiresAt: String? = null,
  val willRenew: Boolean? = null,
  val periodType: String? = null,
  val inGracePeriod: Boolean? = null,
  val store: String? = null,
)

/** `POST /me/entitlement/refresh`. */
@Serializable
data class EntitlementResponseDto(val entitlement: EntitlementDto)

/** `POST /auth/logout` and `DELETE /me`. */
@Serializable
data class OkResponseDto(val ok: Boolean = false)

fun UserDto.toAccount(): Account = Account(id = id, email = email, displayName = displayName)

/**
 * Ported from `ServerEntitlement(dto:)`: every field past `active` read with
 * a default, and an unparseable date read as none rather than failing the
 * answer.
 */
fun EntitlementDto.toDomain(): ServerEntitlement = ServerEntitlement(
  isActive = active,
  productId = productId,
  expiresAt = expiresAt?.let { raw ->
    try {
      Instant.parse(raw)
    } catch (_: DateTimeParseException) {
      null
    }
  },
  willRenew = willRenew ?: false,
  periodType = periodType,
  inGracePeriod = inGracePeriod ?: false,
  store = store,
)
