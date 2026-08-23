import { useRef, useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { apiErrorMessage } from '../api/errors'
import { resolveMediaUrl } from '../lib/media'

type Props = {
  label: string
  accept: string
  currentUrl: string | null
  preview: 'image' | 'video'
  onUpload: (file: File) => Promise<unknown>
  onClear?: () => Promise<unknown>
}

// Shared upload slot for a single media asset (plant picker art, or one of a
// stage's mascot/mascotBg/heroVideo assets). Owns its own upload/clear
// mutation state; the caller's onUpload/onClear do the actual API call plus
// any cache invalidation.
export function AssetUpload({ label, accept, currentUrl, preview, onUpload, onClear }: Props) {
  const [error, setError] = useState<string | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)
  const resolvedUrl = resolveMediaUrl(currentUrl)

  const upload = useMutation({
    mutationFn: (file: File) => onUpload(file),
    onSuccess: () => {
      setError(null)
      if (fileInput.current) fileInput.current.value = ''
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const clear = useMutation({
    mutationFn: () => {
      if (!onClear) return Promise.resolve()
      return onClear()
    },
    onSuccess: () => setError(null),
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <div className="field">
      <label>{label}</label>
      {resolvedUrl ? (
        <div style={{ marginBottom: 8 }}>
          {preview === 'image' ? (
            <img
              src={resolvedUrl}
              alt={label}
              style={{ maxWidth: 160, maxHeight: 160, borderRadius: 10, display: 'block' }}
            />
          ) : (
            <video
              src={resolvedUrl}
              controls
              muted
              loop
              style={{ maxWidth: 240, borderRadius: 10, display: 'block' }}
            />
          )}
        </div>
      ) : (
        <div className="subtitle-cell" style={{ marginBottom: 8 }}>
          Not uploaded yet.
        </div>
      )}
      <div className="inline-form">
        <input
          ref={fileInput}
          type="file"
          accept={accept}
          style={{ width: 'auto' }}
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) upload.mutate(file)
          }}
        />
        {upload.isPending && <span className="muted">Uploading…</span>}
        {onClear && resolvedUrl && (
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => clear.mutate()}
            disabled={clear.isPending}
          >
            Clear
          </button>
        )}
      </div>
      {error && (
        <div className="error-banner" style={{ marginTop: 8 }}>
          {error}
        </div>
      )}
    </div>
  )
}
