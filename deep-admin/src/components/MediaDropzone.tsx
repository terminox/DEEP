import { useId, useRef, useState } from 'react'
import { apiErrorMessage } from '../api/errors'
import { resolveMediaUrl } from '../lib/media'
import { readMediaDuration } from '../lib/mediaDuration'
import { MEDIA_KINDS, fileExtension, formatBytes } from '../lib/mediaKinds'
import type { MediaKind } from '../lib/mediaKinds'

export type MediaDropzoneProps = {
  label: string
  kind: MediaKind
  /** Current value for preview. Absolute or /media-relative; run through resolveMediaUrl. */
  currentUrl: string | null
  /** Runs the real upload. Call onProgress(0-100) to drive the bar. */
  onUpload: (file: File, onProgress: (percent: number) => void) => Promise<void>
  /** Omit to hide the Clear button. May be sync (clears form state) or async (DELETE). */
  onClear?: () => void | Promise<void>
  /** Decoded length of an audio/video pick, from local metadata, before the upload resolves. */
  onDurationDetected?: (seconds: number) => void
  /** Renders an "or paste a link" input beneath the zone. */
  urlInput?: { value: string; onChange: (value: string) => void; placeholder?: string }
  hint?: string
  disabled?: boolean
}

// Drag-and-drop upload slot for a single media asset. The preview lives
// outside the drop target - nesting an <audio controls> inside a <button>
// breaks the transport controls - and the drop target itself is a real
// <button> so click/focus/Enter/Space come for free.
export function MediaDropzone({
  label,
  kind,
  currentUrl,
  onUpload,
  onClear,
  onDurationDetected,
  urlInput,
  hint,
  disabled,
}: MediaDropzoneProps) {
  const [dragging, setDragging] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [percent, setPercent] = useState(0)
  const [clearing, setClearing] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const depth = useRef(0)
  const urlFieldId = useId()
  const fileInput = useRef<HTMLInputElement>(null)

  const rule = MEDIA_KINDS[kind]
  const resolvedUrl = resolveMediaUrl(currentUrl)
  const busy = uploading || clearing
  const locked = disabled || busy

  const startUpload = async (file: File) => {
    setError(null)

    const ext = fileExtension(file.name)
    if (!rule.extensions.includes(ext)) {
      setError(`Unsupported file type. Accepted: ${rule.extensions.join(', ')}.`)
      return
    }
    if (file.size > rule.maxBytes) {
      setError(`File is too large. Max ${formatBytes(rule.maxBytes)}.`)
      return
    }

    if (onDurationDetected && kind !== 'image') {
      // Best-effort - never blocks or fails the upload.
      readMediaDuration(file).then((duration) => {
        if (duration != null) onDurationDetected(duration)
      })
    }

    setUploading(true)
    setPercent(0)
    try {
      await onUpload(file, setPercent)
    } catch (e) {
      setError(apiErrorMessage(e))
    } finally {
      setUploading(false)
      setPercent(0)
    }
  }

  const handleClear = async () => {
    if (!onClear) return
    setError(null)
    setClearing(true)
    try {
      await onClear()
    } catch (e) {
      setError(apiErrorMessage(e))
    } finally {
      setClearing(false)
    }
  }

  return (
    <div className="field">
      <label>{label}</label>
      {resolvedUrl && (
        <div className="dropzone-preview">
          {kind === 'image' && <img src={resolvedUrl} alt={label} />}
          {kind === 'audio' && <audio controls src={resolvedUrl} />}
          {kind === 'video' && <video controls muted loop src={resolvedUrl} />}
          {onClear && (
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={handleClear}
              disabled={busy}
            >
              Clear
            </button>
          )}
        </div>
      )}
      <div
        className={`dropzone${dragging ? ' dropzone-active' : ''}${locked ? ' dropzone-disabled' : ''}`}
        onDragEnter={(e) => {
          e.preventDefault()
          depth.current += 1
          setDragging(true)
        }}
        onDragOver={(e) => {
          e.preventDefault()
          e.dataTransfer.dropEffect = 'copy'
        }}
        onDragLeave={(e) => {
          e.preventDefault()
          depth.current -= 1
          if (depth.current <= 0) {
            depth.current = 0
            setDragging(false)
          }
        }}
        onDrop={(e) => {
          e.preventDefault()
          depth.current = 0
          setDragging(false)
          if (locked) return
          const files = e.dataTransfer.files
          if (files.length === 0) return
          if (files.length > 1) {
            setError('Drop one file at a time.')
            return
          }
          startUpload(files[0])
        }}
      >
        <button
          type="button"
          className="dropzone-cta"
          disabled={locked}
          onClick={() => fileInput.current?.click()}
        >
          {uploading ? 'Uploading…' : 'Choose a file or drop it here'}
        </button>
        <input
          ref={fileInput}
          type="file"
          hidden
          accept={rule.accept}
          disabled={locked}
          onChange={(e) => {
            const file = e.target.files?.[0]
            e.target.value = ''
            if (file) startUpload(file)
          }}
        />
        {uploading && (
          <div className="dropzone-progress">
            <div style={{ width: `${percent}%` }} />
          </div>
        )}
        <div className="dropzone-hint">{hint ?? rule.hint}</div>
      </div>
      {urlInput && (
        <div className="dropzone-url">
          <label htmlFor={urlFieldId}>or paste a link</label>
          <input
            id={urlFieldId}
            type="text"
            value={urlInput.value}
            onChange={(e) => urlInput.onChange(e.target.value)}
            placeholder={urlInput.placeholder ?? 'https://…'}
            disabled={locked}
          />
        </div>
      )}
      {error && <div className="error-banner">{error}</div>}
    </div>
  )
}
