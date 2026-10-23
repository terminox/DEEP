package io.appbeyond.freelance.deep.shared.persistence

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.UUID

/**
 * The JSON the stores' persisted blobs are written in. Lenient on the way in —
 * a key added by a later build, or one a newer build dropped, never fails a cold
 * launch — and explicit on the way out, so every default is on disk.
 */
internal val StoreJson: Json = Json {
  ignoreUnknownKeys = true
  encodeDefaults = true
  explicitNulls = false
}

/** A [UUID] as its canonical lowercase string. */
object UuidAsStringSerializer : KSerializer<UUID> {
  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("io.appbeyond.freelance.deep.UUID", PrimitiveKind.STRING)

  override fun serialize(encoder: Encoder, value: UUID) = encoder.encodeString(value.toString())

  override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}

/** An [Instant] as an ISO-8601 string, e.g. `2026-07-23T05:00:00Z`. */
object InstantAsStringSerializer : KSerializer<Instant> {
  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("io.appbeyond.freelance.deep.Instant", PrimitiveKind.STRING)

  override fun serialize(encoder: Encoder, value: Instant) = encoder.encodeString(value.toString())

  override fun deserialize(decoder: Decoder): Instant = Instant.parse(decoder.decodeString())
}
