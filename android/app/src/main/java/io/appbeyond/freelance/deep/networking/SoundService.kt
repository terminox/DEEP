package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * DEEP Sound content and a listener's saved sounds. Paths are relative — see
 * [PauseHomeService] for why.
 */
interface SoundService {

  /** Anonymous. Every category, ordered, with its ordered collections and tracks. */
  @GET("sound/home")
  suspend fun home(): SoundHomeDto

  /**
   * Anonymous. iOS passes no `lang` (`APISoundContentRepository.lyrics(trackID:language:)`
   * is called with `language: nil` everywhere today), so this omits the query
   * param too — every language for the track comes back, and the Now Playing
   * screen picks one.
   */
  @GET("sound/tracks/{id}/lyrics")
  suspend fun lyrics(@Path("id") trackId: String): LyricsResponseDto

  /** Auth required. Every playlist the member has, each with its items. */
  @GET("me/playlists")
  suspend fun playlists(): PlaylistsResponseDto

  /** Idempotent: keeping an already-kept track is a success, not an error. */
  @POST("me/playlists/{id}/items")
  suspend fun saveItem(@Path("id") playlistId: String, @Body body: PlaylistItemRequest): PlaylistResponseDto

  /** Idempotent: removing an already-gone track is a success. */
  @DELETE("me/playlists/{id}/items/{trackId}")
  suspend fun removeItem(@Path("id") playlistId: String, @Path("trackId") trackId: String): PlaylistResponseDto
}
