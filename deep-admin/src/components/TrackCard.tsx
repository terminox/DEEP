import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { updateTrack, uploadTrackAudio } from '../api/endpoints'
import type { Track, TrackKind } from '../api/types'
import { TRACK_KINDS } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { formatDuration } from '../lib/media'
import { LyricsEditor } from './LyricsEditor'
import { MediaDropzone } from './MediaDropzone'

type Props = {
  track: Track
  index: number
  count: number
  onMove: (dir: -1 | 1) => void
  onDelete: () => void
  onChanged: () => void
}

export function TrackCard({ track, index, count, onMove, onDelete, onChanged }: Props) {
  const [editing, setEditing] = useState(false)
  const [showLyrics, setShowLyrics] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [title, setTitle] = useState(track.title)
  const [duration, setDuration] = useState(String(track.durationSeconds))
  const [kind, setKind] = useState<TrackKind>(track.kind)
  const [isPremium, setIsPremium] = useState(track.isPremium)

  const save = useMutation({
    mutationFn: () =>
      updateTrack(track.id, {
        title,
        durationSeconds: Number(duration),
        kind,
        isPremium,
      }),
    onSuccess: () => {
      setEditing(false)
      setError(null)
      onChanged()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <div className="panel">
      {error && <div className="error-banner">{error}</div>}

      {editing ? (
        <div>
          <div className="form-row">
            <div className="field">
              <label>Title</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <div className="field">
              <label>Duration (seconds)</label>
              <input
                type="number"
                min={1}
                value={duration}
                onChange={(e) => setDuration(e.target.value)}
              />
            </div>
          </div>
          <div className="form-row">
            <div className="field">
              <label>Kind</label>
              <select value={kind} onChange={(e) => setKind(e.target.value as TrackKind)}>
                {TRACK_KINDS.map((k) => (
                  <option key={k} value={k}>
                    {k}
                  </option>
                ))}
              </select>
            </div>
            <div className="field checkbox-field" style={{ alignSelf: 'end' }}>
              <input
                type="checkbox"
                checked={isPremium}
                onChange={(e) => setIsPremium(e.target.checked)}
              />
              <label>Premium</label>
            </div>
          </div>
          <div className="form-actions">
            <button className="btn" onClick={() => save.mutate()} disabled={save.isPending}>
              Save
            </button>
            <button
              className="btn btn-ghost"
              onClick={() => {
                setEditing(false)
                setTitle(track.title)
                setDuration(String(track.durationSeconds))
                setKind(track.kind)
                setIsPremium(track.isPremium)
                setError(null)
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="row-between">
          <div>
            <div className="title-cell" style={{ fontSize: 16 }}>
              {track.title}
            </div>
            <div className="subtitle-cell">
              {formatDuration(track.durationSeconds)} · {track.kind}
              {track.isPremium && '  · Premium'}
              {track.lyricsLanguages.length > 0 &&
                `  · Lyrics: ${track.lyricsLanguages.join(', ')}`}
            </div>
          </div>
          <div className="row-actions">
            <button
              className="btn btn-ghost btn-icon"
              disabled={index === 0}
              onClick={() => onMove(-1)}
              title="Move up"
            >
              ↑
            </button>
            <button
              className="btn btn-ghost btn-icon"
              disabled={index === count - 1}
              onClick={() => onMove(1)}
              title="Move down"
            >
              ↓
            </button>
            <button className="btn btn-ghost btn-sm" onClick={() => setEditing(true)}>
              Edit
            </button>
            <button className="btn btn-danger btn-sm" onClick={onDelete}>
              Delete
            </button>
          </div>
        </div>
      )}

      {!editing && (
        <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
          <MediaDropzone
            label="Audio"
            kind="audio"
            currentUrl={track.audioUrl}
            onUpload={async (file, onProgress) => {
              await uploadTrackAudio(track.id, file, onProgress)
              onChanged()
            }}
            onDurationDetected={(seconds) => setDuration(String(Math.round(seconds)))}
          />

          <div style={{ marginTop: 16 }}>
            <button className="btn btn-ghost btn-sm" onClick={() => setShowLyrics((v) => !v)}>
              {showLyrics ? 'Hide lyrics' : 'Edit lyrics'}
            </button>
          </div>
          {showLyrics && <LyricsEditor trackId={track.id} onChanged={onChanged} />}
        </div>
      )}
    </div>
  )
}
