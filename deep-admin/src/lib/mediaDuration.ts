// Reads the duration of a locally-picked audio/video file without uploading it,
// so the admin never has to type a duration that must match the real asset.
// Resolves null when the browser can't decode it (e.g. a VBR mp3 with no Xing
// header in Safari) - callers must treat the value as a suggestion, not truth.
export function readMediaDuration(file: File): Promise<number | null> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file)
    const el = document.createElement('audio')
    el.preload = 'metadata'

    const finish = (duration: number | null) => {
      URL.revokeObjectURL(url)
      resolve(duration)
    }

    el.onloadedmetadata = () => {
      finish(Number.isFinite(el.duration) && el.duration > 0 ? el.duration : null)
    }
    el.onerror = () => finish(null)

    el.src = url
  })
}
