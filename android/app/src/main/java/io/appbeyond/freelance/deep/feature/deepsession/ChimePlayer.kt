package io.appbeyond.freelance.deep.feature.deepsession

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import io.appbeyond.freelance.deep.R

/**
 * The bell that closes a practice.
 *
 * Named for the capability, not the pattern — see the project's naming rule.
 * [SilentChime] is the default a preview gets, which is what keeps previews
 * hermetic and silent.
 */
interface ChimePlaying {
  /**
   * Warms the player. Called a whole practice ahead of the strike, not at the
   * moment of ringing: decoding and buffering at ring time would put a gap
   * exactly where the session's last exhale lands.
   */
  fun prepare()

  /** Strikes the bell. Safe to call before [prepare] finishes. */
  fun ring()

  /** Releases the underlying player. */
  fun release()
}

/** Does nothing, audibly. The default in previews and tests. */
class SilentChime : ChimePlaying {
  override fun prepare() = Unit
  override fun ring() = Unit
  override fun release() = Unit
}

/**
 * Plays the bundled chime.
 *
 * Note what is deliberately *not* ported. The iOS version carries a long comment
 * about claiming the `.playback` AVAudioSession category so the ring/silent
 * switch cannot mute the bell. Android's silent switch does not mute
 * `USAGE_MEDIA`, so that problem does not exist here and there is no solution to
 * bring across.
 */
class ChimePlayer(private val context: Context) : ChimePlaying {

  private var player: MediaPlayer? = null
  private var isReady = false
  private var ringWhenReady = false

  override fun prepare() {
    if (player != null) return
    player = MediaPlayer().apply {
      setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_MEDIA)
          // A bell is a sonification, not a piece of music: this is what tells
          // the system it may sound alongside other audio rather than duck it.
          .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
          .build()
      )
      setVolume(VOLUME, VOLUME)
      setOnPreparedListener {
        isReady = true
        if (ringWhenReady) {
          ringWhenReady = false
          start()
        }
      }
      runCatching {
        context.resources.openRawResourceFd(R.raw.session_chime)?.use { fd ->
          setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
        }
        prepareAsync()
      }
    }
  }

  override fun ring() {
    val current = player ?: run {
      prepare()
      ringWhenReady = true
      return
    }
    if (!isReady) {
      ringWhenReady = true
      return
    }
    runCatching {
      current.seekTo(0)
      current.start()
    }
  }

  override fun release() {
    runCatching { player?.release() }
    player = null
    isReady = false
    ringWhenReady = false
  }
}

/** Matching the iOS chime's level — present, never startling. */
private const val VOLUME = 0.6f
