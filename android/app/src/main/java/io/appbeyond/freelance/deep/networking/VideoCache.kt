package io.appbeyond.freelance.deep.networking

import android.content.Context
import android.util.Log
import androidx.annotation.OptIn
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.net.toUri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheWriter
import androidx.media3.datasource.cache.ContentMetadata
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.datasource.okhttp.OkHttpDataSource
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

/**
 * Disk cache for the garden's stage hero loops. Video is never held in memory
 * — ExoPlayer streams straight off the cache — so the cache's whole job is
 * turning "watched once" into "plays instantly offline next launch": the URL
 * overload of `LoopingVideoView` plays through [dataSourceFactory] (a Media3
 * `CacheDataSource`, so the stream itself fills the cache) and calls [warm] to
 * finish the download in the background even if the viewer scrolls away
 * mid-loop.
 *
 * Ported from Deep/Deep/Networking/VideoCache.swift: 512 MB, least recently
 * *played* evicted first (Media3's LRU evictor touches a span on read, as iOS
 * touches the file). iOS keys entries through `ImageLoader.cacheKey` to merge
 * Dev's localhost / mDNS host split; Android has no mDNS host (the emulator and
 * devices reach Dev through one configured host), so the URL itself is the key.
 *
 * One instance per process — Media3 allows only one `SimpleCache` per
 * directory — through [shared]. Screens read it from [LocalVideoCache], whose
 * null default keeps previews hermetic: with no cache the view plays local
 * footage directly and streams remote footage uncached.
 */
@OptIn(UnstableApi::class)
class VideoCache private constructor(context: Context, client: OkHttpClient) {

  private val cache: SimpleCache = SimpleCache(
    File(context.cacheDir, DIRECTORY),
    LeastRecentlyUsedCacheEvictor(DISK_LIMIT_BYTES),
    StandaloneDatabaseProvider(context),
  )

  /*
   * Over the media client, as `DeepSoundService` streams audio: the shared pool
   * and dispatcher, none of the API's headers or bearer token, no call timeout.
   * `DefaultDataSource` wraps it so a local URI would still resolve.
   */
  private val cacheFactory: CacheDataSource.Factory = CacheDataSource.Factory()
    .setCache(cache)
    .setUpstreamDataSourceFactory(DefaultDataSource.Factory(context, OkHttpDataSource.Factory(client)))
    .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

  /** Reads through the cache, filling it from the network on a miss. */
  val dataSourceFactory: DataSource.Factory get() = cacheFactory

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
  private val inFlight = ConcurrentHashMap<String, Job>()

  /**
   * Whether every byte of [url] is on disk — the reduced-motion path holds a
   * still frame only when it can do so without the network. Index lookups
   * only; cheap, but call it off the main thread (the index loads lazily).
   */
  fun isFullyCached(url: String): Boolean {
    val length = ContentMetadata.getContentLength(cache.getContentMetadata(url))
    return length != C.LENGTH_UNSET.toLong() && cache.isCached(url, 0, length)
  }

  /**
   * Downloads [url] into the cache if it isn't there yet. Concurrent calls for
   * the same URL share one download, which outlives the screen that asked;
   * failures are swallowed — the caller is already streaming, and the next
   * mount simply tries again.
   */
  fun warm(url: String) {
    inFlight.computeIfAbsent(url) {
      scope.launch {
        try {
          if (!isFullyCached(url)) {
            CacheWriter(cacheFactory.createDataSource(), DataSpec(url.toUri()), null, null).cache()
          }
        } catch (e: IOException) {
          Log.d(TAG, "Video warm-up failed; the next mount retries.", e)
        } catch (e: IllegalStateException) {
          // A cache torn down under the writer — never worth a crash.
          Log.w(TAG, "Video warm-up abandoned.", e)
        } finally {
          inFlight.remove(url)
        }
      }
    }
  }

  companion object {
    private const val TAG = "VideoCache"
    private const val DIRECTORY = "deep-video"
    private const val DISK_LIMIT_BYTES = 512L * 1024 * 1024

    @Volatile
    private var instance: VideoCache? = null

    /**
     * The process's one cache. The first caller's [client] is the one it keeps;
     * pass `DeepHttp.mediaClient`.
     */
    fun shared(context: Context, client: OkHttpClient): VideoCache =
      instance ?: synchronized(this) {
        instance ?: VideoCache(context.applicationContext, client).also { instance = it }
      }
  }
}

/**
 * The hero-footage cache. The shell provides the process instance
 * ([VideoCache.shared]); the null default keeps previews hermetic.
 */
val LocalVideoCache = staticCompositionLocalOf<VideoCache?> { null }
