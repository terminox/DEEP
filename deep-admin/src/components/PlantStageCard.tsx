import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { deleteStageAsset, updateStage, uploadStageAsset } from '../api/endpoints'
import type { PlantStage } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { MediaDropzone } from './MediaDropzone'

type Props = {
  stage: PlantStage
  index: number
  count: number
  onMove: (dir: -1 | 1) => void
  onDelete: () => void
  onChanged: () => void
}

export function PlantStageCard({ stage, index, count, onMove, onDelete, onChanged }: Props) {
  const [editing, setEditing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [name, setName] = useState(stage.name)
  const [sunlightRequired, setSunlightRequired] = useState(String(stage.sunlightRequired))

  const save = useMutation({
    mutationFn: () =>
      updateStage(stage.id, {
        name,
        sunlightRequired: Number(sunlightRequired),
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
              <label>Name</label>
              <input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="field">
              <label>Sunlight required (cumulative)</label>
              <input
                type="number"
                min={0}
                value={sunlightRequired}
                onChange={(e) => setSunlightRequired(e.target.value)}
              />
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
                setName(stage.name)
                setSunlightRequired(String(stage.sunlightRequired))
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
              {stage.name}
            </div>
            <div className="subtitle-cell">{stage.sunlightRequired} sunlight to reach</div>
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
          <div className="panel-title" style={{ marginBottom: 10 }}>
            Assets
          </div>
          <div className="form-row">
            <MediaDropzone
              label="Mascot — no background"
              kind="image"
              currentUrl={stage.mascotUrl}
              onUpload={async (file, onProgress) => {
                await uploadStageAsset(stage.id, 'mascot', file, onProgress)
                onChanged()
              }}
              onClear={async () => {
                await deleteStageAsset(stage.id, 'mascot')
                onChanged()
              }}
            />
            <MediaDropzone
              label="Mascot — with background (optional)"
              kind="image"
              currentUrl={stage.mascotBgUrl}
              onUpload={async (file, onProgress) => {
                await uploadStageAsset(stage.id, 'mascotBg', file, onProgress)
                onChanged()
              }}
              onClear={async () => {
                await deleteStageAsset(stage.id, 'mascotBg')
                onChanged()
              }}
            />
          </div>
          <MediaDropzone
            label="Hero video"
            kind="video"
            currentUrl={stage.heroVideoUrl}
            onUpload={async (file, onProgress) => {
              await uploadStageAsset(stage.id, 'heroVideo', file, onProgress)
              onChanged()
            }}
            onClear={async () => {
              await deleteStageAsset(stage.id, 'heroVideo')
              onChanged()
            }}
          />
        </div>
      )}
    </div>
  )
}
