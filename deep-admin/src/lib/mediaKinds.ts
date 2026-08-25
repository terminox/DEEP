// Client mirror of the server's upload allowlist. The source of truth lives
// in deep-api/src/lib/upload.ts as MEDIA_RULES — keep these two in sync by
// hand. Two allowlists in two languages will drift otherwise.

export type MediaKind = 'image' | 'audio' | 'video'

type Rule = {
  accept: string // the <input accept> attribute
  extensions: string[] // lowercase, with leading dot - validated client-side before upload
  maxBytes: number
  hint: string // shown under the drop target, e.g. 'PNG, JPG or WebP - up to 10 MB'
}

export const MEDIA_KINDS: Record<MediaKind, Rule> = {
  image: {
    accept: 'image/png,image/jpeg,image/webp',
    extensions: ['.png', '.jpg', '.jpeg', '.webp'],
    maxBytes: 10 * 1024 * 1024,
    hint: 'PNG, JPG or WebP - up to 10 MB',
  },
  audio: {
    accept: 'audio/mpeg,audio/mp4,audio/aac,.mp3,.m4a,.aac',
    extensions: ['.mp3', '.m4a', '.aac'],
    maxBytes: 25 * 1024 * 1024,
    hint: 'MP3, M4A or AAC - up to 25 MB',
  },
  video: {
    accept: 'video/mp4,video/quicktime',
    extensions: ['.mp4', '.mov'],
    maxBytes: 200 * 1024 * 1024,
    hint: 'MP4 or MOV - up to 200 MB',
  },
}

// Validate on extension and size, not file.type - Safari/macOS reports
// audio/x-m4a or an empty string for valid picks, and the server checks
// extension, so the two must agree.
export function fileExtension(name: string): string {
  const dot = name.lastIndexOf('.')
  if (dot < 0) return ''
  return name.slice(dot).toLowerCase()
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB']
  let value = bytes / 1024
  let unitIndex = 0
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024
    unitIndex += 1
  }
  return `${value.toFixed(1)} ${units[unitIndex]}`
}
