import { useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createTrack,
  deleteTrack,
  getCollection,
  reorderTracks,
} from '../api/endpoints'
import { TRACK_KINDS, type CollectionDetail, type TrackKind } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PaletteSwatch } from '../components/PaletteSwatch'
import { TrackCard } from '../components/TrackCard'

function CollectionDetailPage() {
  const { id = '' } = useParams()
  const qc = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['collection', id],
    queryFn: () => getCollection(id),
    enabled: !!id,
  })

  const [title, setTitle] = useState('')
  const [duration, setDuration] = useState('60')
  const [kind, setKind] = useState<TrackKind>('INSTRUMENTAL')
  const [isPremium, setIsPremium] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  const invalidate = () => qc.invalidateQueries({ queryKey: ['collection', id] })

  const create = useMutation({
    mutationFn: () =>
      createTrack({
        collectionId: id,
        title,
        durationSeconds: Number(duration),
        kind,
        isPremium,
      }),
    onSuccess: () => {
      setTitle('')
      setDuration('60')
      setKind('INSTRUMENTAL')
      setIsPremium(false)
      setFormError(null)
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: (trackId: string) => deleteTrack(trackId),
    onSuccess: invalidate,
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderTracks(ids),
    onSuccess: invalidate,
  })

  const handleCreate = (e: FormEvent) => {
    e.preventDefault()
    create.mutate()
  }

  const handleMove = (tracks: CollectionDetail['tracks'], index: number, dir: -1 | 1) => {
    const ids = moveItem(tracks.map((t) => t.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  return (
    <div>
      <Link to="/collections" className="back-link">
        ← Back to collections
      </Link>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading || !data ? (
        <div className="state">Loading…</div>
      ) : (
        <>
          <div className="page-header">
            <div>
              <h1>{data.title}</h1>
              <div className="page-subtitle">{data.subtitle}</div>
            </div>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <PaletteSwatch palette={data.palette} />
              {data.isPremium && <span className="badge badge-premium">Premium</span>}
            </div>
          </div>

          <div className="panel">
            <div className="panel-title">Add track</div>
            {formError && <div className="error-banner">{formError}</div>}
            <form onSubmit={handleCreate}>
              <div className="form-row">
                <div className="field">
                  <label>Title</label>
                  <input value={title} onChange={(e) => setTitle(e.target.value)} required />
                </div>
                <div className="field">
                  <label>Duration (seconds)</label>
                  <input
                    type="number"
                    min={1}
                    value={duration}
                    onChange={(e) => setDuration(e.target.value)}
                    required
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
                    id="trackPremium"
                    type="checkbox"
                    checked={isPremium}
                    style={{ width: 'auto' }}
                    onChange={(e) => setIsPremium(e.target.checked)}
                  />
                  <label htmlFor="trackPremium">Premium</label>
                </div>
              </div>
              <div className="form-actions">
                <button className="btn" type="submit" disabled={create.isPending}>
                  Add track
                </button>
              </div>
            </form>
          </div>

          <div className="row-between" style={{ marginBottom: 12 }}>
            <h2 style={{ fontSize: 18 }}>Tracks ({data.tracks.length})</h2>
          </div>

          {data.tracks.length === 0 ? (
            <div className="panel empty">No tracks yet.</div>
          ) : (
            <div className="stack">
              {data.tracks.map((track, i) => (
                <TrackCard
                  key={track.id}
                  track={track}
                  index={i}
                  count={data.tracks.length}
                  onMove={(dir) => handleMove(data.tracks, i, dir)}
                  onDelete={() => {
                    if (confirm(`Delete track "${track.title}"?`)) remove.mutate(track.id)
                  }}
                  onChanged={invalidate}
                />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default CollectionDetailPage
