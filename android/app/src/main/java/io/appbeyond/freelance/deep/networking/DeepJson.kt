package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.contextual
import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaType
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

/**
 * The one `Json` every Deep response is decoded with.
 *
 * Configured to match `APIClient`'s bare `JSONDecoder()` exactly: the wire format
 * is plain camelCase with no key strategy, so nothing is transformed here either.
 * `DTOs.swift` says the same thing in its header — "these mirror the backend's
 * JSON exactly (camelCase, so no key strategy needed)".
 *
 * `ignoreUnknownKeys` is what lets the backend add a field without breaking every
 * installed build — Swift's `Decodable` ignores unknown keys by default, kotlinx
 * throws, and that difference would otherwise turn a routine API addition into a
 * forced app update.
 */
val DeepJson: Json = Json {
  ignoreUnknownKeys = true

  // A key present with a null value and a key absent mean the same thing to this
  // backend: `serialize.ts` emits `undefined` for an absent relation and `null`
  // for an empty column, sometimes for the same field. Both must land on the
  // property's default.
  explicitNulls = false

  serializersModule = SerializersModule {
    contextual(IsoInstantSerializer)
  }
}

/** The one content type Deep speaks, shared by the client and the converter. */
val DeepJsonMediaType: MediaType = "application/json; charset=utf-8".toMediaType()

/**
 * Reads the ISO-8601 strings deep-api puts on the wire.
 *
 * Prisma is not consistent about the offset it writes: a `DateTime` column
 * serialized through `toISOString()` ends in `Z`, while a value that has been
 * round-tripped through the database driver can arrive with a numeric offset
 * (`+07:00`). Both are valid ISO-8601 and both must parse, so the primary path is
 * `ISO_OFFSET_DATE_TIME`, which accepts `Z` as an offset like any other.
 *
 * `java.time` rather than a desugared or third-party clock: minSdk is 26, so it
 * is on the device natively and behaves identically to the JVM tests in
 * `:core:model`.
 *
 * Registered contextually on [DeepJson], so a DTO field only needs `@Contextual`.
 */
object IsoInstantSerializer : KSerializer<Instant> {

  override val descriptor: SerialDescriptor =
    PrimitiveSerialDescriptor("java.time.Instant", PrimitiveKind.STRING)

  override fun serialize(encoder: Encoder, value: Instant) {
    encoder.encodeString(DateTimeFormatter.ISO_INSTANT.format(value))
  }

  override fun deserialize(decoder: Decoder): Instant = parse(decoder.decodeString())

  /** Exposed so a repository can parse a date it received as a bare `String`. */
  fun parse(text: String): Instant =
    try {
      OffsetDateTime.parse(text, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
    } catch (notAnOffset: DateTimeParseException) {
      // Leaves the failure to Instant.parse, whose message names the position it
      // gave up at — more use to whoever reads the crash than this one's.
      Instant.parse(text)
    }
}
