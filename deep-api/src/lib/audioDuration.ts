import { parseFile } from "music-metadata";
import { resolveMediaFile } from "./mediaFiles.js";

/**
 * The real length of a stored audio file, in whole seconds.
 *
 * The Global Pause meditation runs for exactly as long as its track, so this
 * number is the length of the event itself — it has to come from the file. The
 * admin browser also reads a duration when a file is picked, but that is a hint
 * (`deep-admin/src/lib/mediaDuration.ts` resolves null whenever the browser
 * can't decode the container) and a hint has no business deciding how long a
 * session lasts.
 *
 * Null when there is nothing to measure — an absolute third-party URL, a
 * missing file, or a container this can't read. Callers decide what that means.
 */
export async function readAudioDurationSeconds(
  relPath: string | null | undefined,
): Promise<number | null> {
  const abs = resolveMediaFile(relPath);
  if (!abs) return null;
  try {
    // `duration: true` costs a full frame scan on a VBR mp3 with no Xing
    // header — exactly the case the browser hint gives up on. Uploads are
    // capped at 25MB (MEDIA_RULES.audio) so the scan stays cheap, and it only
    // runs when the pause config is saved, a track is uploaded, or the seed runs.
    const { format } = await parseFile(abs, { duration: true });
    const seconds = format.duration;
    if (typeof seconds !== "number" || !Number.isFinite(seconds) || seconds <= 0) return null;
    return Math.round(seconds);
  } catch {
    return null;
  }
}
