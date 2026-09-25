package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.auth.Account
import kotlinx.serialization.Serializable

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

/** `POST /auth/signup` and `POST /auth/login`. */
@Serializable
data class AuthResponseDto(
  val user: UserDto,
  val accessToken: String,
  val refreshToken: String,
  val expiresIn: Int = 0,
)

/** `GET /me`. */
@Serializable
data class MeResponseDto(val user: UserDto)

/** `POST /auth/logout` and `DELETE /me`. */
@Serializable
data class OkResponseDto(val ok: Boolean = false)

fun UserDto.toAccount(): Account = Account(id = id, email = email, displayName = displayName)
