import { useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createStage,
  deleteStage,
  getPlant,
  listPlants,
  reorderStages,
  updatePlant,
  uploadPlantImage,
} from '../api/endpoints'
import { PALETTES, type Palette, type PlantDetail } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PaletteSwatch } from '../components/PaletteSwatch'
import { PlantStageCard } from '../components/PlantStageCard'
import { MediaDropzone } from '../components/MediaDropzone'

function PlantDetailPage() {
  const { id = '' } = useParams()
  const qc = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['plant', id],
    queryFn: () => getPlant(id),
    enabled: !!id,
  })

  // Fetched to compute the "onboarding will show no plants" warning below.
  const allPlants = useQuery({
    queryKey: ['plants'],
    queryFn: () => listPlants(),
  })

  // ---- Plant edit form (populated once the plant loads) ----
  type EditState = {
    name: string
    tagline: string
    palette: Palette
    isPremium: boolean
    isDefault: boolean
    isActive: boolean
  }
  const [edit, setEdit] = useState<EditState | null>(null)
  const [editError, setEditError] = useState<string | null>(null)
  const [editInitializedFor, setEditInitializedFor] = useState<string | null>(null)

  // Adjust state during render rather than in an effect (React's recommended
  // pattern for "reset derived state when the source data changes") — avoids
  // the extra render pass a useEffect-based setState would trigger.
  if (data && editInitializedFor !== data.id) {
    setEdit({
      name: data.name,
      tagline: data.tagline,
      palette: data.palette,
      isPremium: data.isPremium,
      isDefault: data.isDefault,
      isActive: data.isActive,
    })
    setEditInitializedFor(data.id)
  }

  const invalidate = () => qc.invalidateQueries({ queryKey: ['plant', id] })
  const invalidateAll = () => {
    invalidate()
    qc.invalidateQueries({ queryKey: ['plants'] })
  }

  const savePlant = useMutation({
    mutationFn: () => {
      if (!edit) throw new Error('not ready')
      return updatePlant(id, edit)
    },
    onSuccess: () => {
      setEditError(null)
      invalidateAll()
    },
    onError: (e) => setEditError(apiErrorMessage(e)),
  })

  // ---- Add-stage form ----
  const [stageName, setStageName] = useState('')
  const [sunlightRequired, setSunlightRequired] = useState('0')
  const [stageFormError, setStageFormError] = useState<string | null>(null)

  const createStageMut = useMutation({
    mutationFn: () =>
      createStage(id, {
        name: stageName,
        sunlightRequired: Number(sunlightRequired),
      }),
    onSuccess: () => {
      setStageName('')
      setSunlightRequired('0')
      setStageFormError(null)
      invalidate()
    },
    onError: (e) => setStageFormError(apiErrorMessage(e)),
  })

  const [stageListError, setStageListError] = useState<string | null>(null)

  const removeStage = useMutation({
    mutationFn: (stageId: string) => deleteStage(stageId),
    onSuccess: () => {
      setStageListError(null)
      invalidate()
    },
    onError: (e) => setStageListError(apiErrorMessage(e)),
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderStages(id, ids),
    onSuccess: () => {
      setStageListError(null)
      invalidate()
    },
    onError: (e) => setStageListError(apiErrorMessage(e)),
  })

  const handleMove = (stages: PlantDetail['stages'], index: number, dir: -1 | 1) => {
    const ids = moveItem(stages.map((s) => s.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  const handleCreateStage = (e: FormEvent) => {
    e.preventDefault()
    createStageMut.mutate()
  }

  // Client-side hint only — the server re-validates the full ladder on every
  // mutation and is the source of truth (surfaced above as invalid_thresholds).
  const lastThreshold = data && data.stages.length > 0
    ? data.stages[data.stages.length - 1].sunlightRequired
    : null
  const enteredThreshold = Number(sunlightRequired)
  const thresholdHint =
    lastThreshold === null
      ? enteredThreshold !== 0
        ? 'The first stage should require 0 sunlight.'
        : null
      : enteredThreshold <= lastThreshold
        ? `This should be greater than the previous stage's ${lastThreshold}.`
        : null

  const noActiveDefaults =
    allPlants.data !== undefined &&
    !allPlants.data.some((p) => p.isActive && p.isDefault && !p.isPremium)

  return (
    <div>
      <Link to="/plants" className="back-link">
        ← Back
      </Link>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading || !data ? (
        <div className="state">Loading…</div>
      ) : (
        <>
          <div className="page-header">
            <div>
              <h1>{data.name}</h1>
              <div className="page-subtitle">{data.tagline}</div>
            </div>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <PaletteSwatch palette={data.palette} />
              {data.isPremium && <span className="badge badge-premium">Premium</span>}
              {data.isDefault && <span className="badge">Default</span>}
              <span className="badge">{data.isActive ? 'Active' : 'Draft'}</span>
            </div>
          </div>

          {data.isDefault && data.isPremium && (
            <div className="warning-banner">
              This plant is Default but also Premium — premium plants are hidden from onboarding
              entirely, so it won&apos;t appear there.
            </div>
          )}
          {noActiveDefaults && (
            <div className="warning-banner">
              Onboarding will show no plants — no active, non-premium plant is marked Default.
            </div>
          )}

          {edit && (
            <div className="panel">
              <div className="panel-title">Edit plant</div>
              {editError && <div className="error-banner">{editError}</div>}
              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  savePlant.mutate()
                }}
              >
                <div className="form-row">
                  <div className="field">
                    <label>Name</label>
                    <input
                      value={edit.name}
                      onChange={(e) => setEdit({ ...edit, name: e.target.value })}
                      required
                    />
                  </div>
                  <div className="field">
                    <label>Palette</label>
                    <select
                      value={edit.palette}
                      onChange={(e) => setEdit({ ...edit, palette: e.target.value as Palette })}
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
                  <label>Tagline</label>
                  <input
                    value={edit.tagline}
                    onChange={(e) => setEdit({ ...edit, tagline: e.target.value })}
                    required
                  />
                </div>
                <div className="form-row">
                  <div className="field checkbox-field">
                    <input
                      id="editPlantPremium"
                      type="checkbox"
                      checked={edit.isPremium}
                      onChange={(e) => setEdit({ ...edit, isPremium: e.target.checked })}
                    />
                    <label htmlFor="editPlantPremium">Premium</label>
                  </div>
                  <div className="field checkbox-field">
                    <input
                      id="editPlantDefault"
                      type="checkbox"
                      checked={edit.isDefault}
                      onChange={(e) => setEdit({ ...edit, isDefault: e.target.checked })}
                    />
                    <label htmlFor="editPlantDefault">Default</label>
                  </div>
                </div>
                <div className="field checkbox-field">
                  <input
                    id="editPlantActive"
                    type="checkbox"
                    checked={edit.isActive}
                    onChange={(e) => setEdit({ ...edit, isActive: e.target.checked })}
                  />
                  <label htmlFor="editPlantActive">Active</label>
                </div>
                <div className="form-actions">
                  <button className="btn" type="submit" disabled={savePlant.isPending}>
                    Save plant
                  </button>
                </div>
              </form>

              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
                <MediaDropzone
                  label="Picker image"
                  kind="image"
                  currentUrl={data.imageUrl}
                  onUpload={async (file, onProgress) => {
                    await uploadPlantImage(id, file, onProgress)
                    invalidateAll()
                  }}
                />
              </div>
            </div>
          )}

          <div className="panel">
            <div className="panel-title">Add stage</div>
            {stageFormError && <div className="error-banner">{stageFormError}</div>}
            <form onSubmit={handleCreateStage}>
              <div className="form-row">
                <div className="field">
                  <label>Name</label>
                  <input value={stageName} onChange={(e) => setStageName(e.target.value)} required />
                </div>
                <div className="field">
                  <label>Sunlight required (cumulative)</label>
                  <input
                    type="number"
                    min={0}
                    value={sunlightRequired}
                    onChange={(e) => setSunlightRequired(e.target.value)}
                    required
                  />
                  {thresholdHint && <div className="subtitle-cell">{thresholdHint}</div>}
                </div>
              </div>
              <div className="form-actions">
                <button className="btn" type="submit" disabled={createStageMut.isPending}>
                  Add stage
                </button>
              </div>
            </form>
          </div>

          <h2 className="section-title">Stages ({data.stages.length})</h2>

          {stageListError && <div className="error-banner">{stageListError}</div>}

          {data.stages.length === 0 ? (
            <div className="panel empty">No stages yet.</div>
          ) : (
            <div className="stack">
              {data.stages.map((stage, i) => (
                <PlantStageCard
                  key={stage.id}
                  stage={stage}
                  index={i}
                  count={data.stages.length}
                  onMove={(dir) => handleMove(data.stages, i, dir)}
                  onDelete={() => {
                    if (confirm(`Delete stage "${stage.name}"?`)) removeStage.mutate(stage.id)
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

export default PlantDetailPage
