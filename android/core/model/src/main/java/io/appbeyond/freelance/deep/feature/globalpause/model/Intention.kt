package io.appbeyond.freelance.deep.feature.globalpause.model

/**
 * A shared intention for the pause. [key] is the backend's stable identity
 * (what reflections submit); [label] is display copy.
 *
 * The two are deliberately independent: deriving the key from the label would
 * make the wire format a function of the English wording, so translating
 * "Someone I love" would start submitting Thai characters. Keys are written
 * out; labels are translated.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/Intention.swift. The
 * offline sample set's labels are resources in `:app`; only its keys live here.
 */
data class Intention(val key: String, val label: String) {

  val id: String get() = key

  companion object {
    /** The backend seed's keys, in its display order — the offline fallback. */
    val SAMPLE_KEYS: List<String> = listOf("peace", "healing", "gratitude", "someone-i-love", "other")
  }
}
