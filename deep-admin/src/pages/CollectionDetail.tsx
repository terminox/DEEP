import { useEffect, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createTrack,
  deleteTrack,
  getCollection,
  listCategories,
  reorderTracks,
  updateCollection,
  uploadMedia,
  uploadTrackAudio,
} from '../api/endpoints'
import {
  PALETTES,
  TRACK_KINDS,
  type CollectionDetail,
  type Palette,
  type TrackKind,
} from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PaletteSwatch } from '../components/PaletteSwatch'
import { PendingBar } from '../components/PendingBar'
import { PendingBadge } from '../components/PendingBadge'
import { TrackCard } from '../components/TrackCard'
import { MediaDropzone } from '../components/MediaDropzone'

function CollectionDetailPage() {
  const { id = '' } = useParams()
  const qc = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['collection', id],
    queryFn: () => getCollection(id),
    enabled: !!id,
  })

  const categories = useQuery({
    queryKey: ['categories'],
    queryFn: () => listCategories(),
  })

  const [title, setTitle] = useState('')
  const [duration, setDuration] = useState('60')
  const [kind, setKind] = useState<TrackKind>('INSTRUMENTAL')
  const [isPremium, setIsPremium] = useState(false)
  const [pendingAudio, setPendingAudio] = useState<File | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  // ---- Collection edit form (populated once the collection loads) ----
  type EditState = {
    categoryId: string
    title: string
    subtitle: string
    palette: Palette
    imageUrl: string
    isPremium: boolean
  }
  const [edit, setEdit] = useState<EditState | null>(null)
  const [editError, setEditError] = useState<string | null>(null)

  useEffect(() => {
    if (data && !edit) {
      setEdit({
        categoryId: data.categoryId,
        title: data.title,
        subtitle: data.subtitle,
        palette: data.palette,
        imageUrl: data.imageUrl ?? '',
        isPremium: data.isPremium,
      })
    }
  }, [data, edit])

  const invalidate = () => qc.invalidateQueries({ queryKey: ['collection', id] })

  const saveCollection = useMutation({
    mutationFn: () => {
      if (!edit) throw new Error('not ready')
      return updateCollection(id, {
        categoryId: edit.categoryId,
        title: edit.title,
        subtitle: edit.subtitle,
        palette: edit.palette,
        imageUrl: edit.imageUrl.trim() ? edit.imageUrl.trim() : null,
        isPremium: edit.isPremium,
      })
    },
    onSuccess: () => {
      setEditError(null)
      invalidate()
      qc.invalidateQueries({ queryKey: ['collections'] })
      qc.invalidateQueries({ queryKey: ['categories'] })
    },
    onError: (e) => setEditError(apiErrorMessage(e)),
  })

  const create = useMutation({
    mutationFn: async () => {
      const track = await createTrack({
        collectionId: id,
        title,
        durationSeconds: Number(duration),
        kind,
        isPremium,
      })
      // The row exists from here on, so a failed audio attach must not surface
      // as a failed create — retrying the whole mutation would add a second,
      // duplicate track. Report it instead and let the admin retry the upload
      // from the track's own Audio field.
      if (pendingAudio) {
        try {
          await uploadTrackAudio(track.id, pendingAudio)
        } catch (e) {
          return { audioError: apiErrorMessage(e) }
        }
      }
      return { audioError: null }
    },
    onSuccess: ({ audioError }) => {
      setTitle('')
      setDuration('60')
      setKind('INSTRUMENTAL')
      setIsPremium(false)
      setPendingAudio(null)
      setFormError(
        audioError
          ? `Track created, but the audio upload failed: ${audioError} — attach it from the track's Audio field below.`
          : null,
      )
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

  const backTo = data ? `/categories/${data.categoryId}` : '/collections'

  return (
    <div>
      <Link to={backTo} className="back-link">
        ← Back
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
              {!data.isActive && <span className="badge">Hidden</span>}
              <PendingBadge pending={data.pending} />
            </div>
          </div>

          <PendingBar entityKey={`SOUND_COLLECTION:${data.id}`} />

          {edit && (
            <div className="panel">
              <div className="panel-title">Edit collection</div>
              {editError && <div className="error-banner">{editError}</div>}
              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  saveCollection.mutate()
                }}
              >
                <div className="form-row">
                  <div className="field">
                    <label>Category</label>
                    <select
                      value={edit.categoryId}
                      onChange={(e) => setEdit({ ...edit, categoryId: e.target.value })}
                      required
                    >
                      {categories.data?.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.title}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="field">
                    <label>Palette</label>
                    <select
                      value={edit.palette}
                      onChange={(e) =>
                        setEdit({ ...edit, palette: e.target.value as Palette })
                      }
                    >
                      {PALETTES.map((p) => (
                        <option key={p} value={p}>
                          {p}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <div className="field">
                  <label>Title</label>
                  <input
                    value={edit.title}
                    onChange={(e) => setEdit({ ...edit, title: e.target.value })}
                    required
                  />
                </div>
                <div className="field">
                  <label>Subtitle</label>
                  <input
                    value={edit.subtitle}
                    onChange={(e) => setEdit({ ...edit, subtitle: e.target.value })}
                    required
                  />
                </div>
                <MediaDropzone
                  label="Cover image"
                  kind="image"
                  currentUrl={edit.imageUrl || null}
                  onUpload={async (file, onProgress) => {
                    const media = await uploadMedia('image', file, onProgress)
                    setEdit((f) => (f ? { ...f, imageUrl: media.path } : f))
                  }}
                  onClear={() => setEdit((f) => (f ? { ...f, imageUrl: '' } : f))}
                  urlInput={{
                    value: edit.imageUrl,
                    onChange: (v) => setEdit((f) => (f ? { ...f, imageUrl: v } : f)),
                    placeholder: 'https://…',
                  }}
                />
                <div className="field checkbox-field">
                  <input
                    id="editColPremium"
                    type="checkbox"
                    checked={edit.isPremium}
                    onChange={(e) => setEdit({ ...edit, isPremium: e.target.checked })}
                  />
                  <label htmlFor="editColPremium">Premium</label>
                </div>
                <div className="form-actions">
                  <button className="btn" type="submit" disabled={saveCollection.isPending}>
                    Save collection
                  </button>
                </div>
              </form>
            </div>
          )}

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
                    onChange={(e) => setIsPremium(e.target.checked)}
                  />
                  <label htmlFor="trackPremium">Premium</label>
                </div>
              </div>
              <MediaDropzone
                label="Audio"
                kind="audio"
                currentUrl={null}
                onUpload={async (file) => setPendingAudio(file)}
                onDurationDetected={(seconds) => setDuration(String(Math.round(seconds)))}
                hint={
                  pendingAudio
                    ? `Selected: ${pendingAudio.name} — uploads once the track is created`
                    : undefined
                }
              />
              <div className="form-actions">
                <button className="btn" type="submit" disabled={create.isPending}>
                  Add track
                </button>
              </div>
            </form>
          </div>

          <div className="section-header">
            <h2 className="section-title">Tracks ({data.tracks.length})</h2>
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
