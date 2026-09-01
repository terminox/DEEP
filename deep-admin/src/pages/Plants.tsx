import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createPlant,
  deletePlant,
  listPlants,
  reorderPlants,
  updatePlant,
} from '../api/endpoints'
import { PALETTES, type Palette, type Plant } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PaletteSwatch } from '../components/PaletteSwatch'
import { PendingBadge } from '../components/PendingBadge'

type FormState = {
  id: string
  name: string
  tagline: string
  palette: Palette
  isPremium: boolean
  isDefault: boolean
  isActive: boolean
}

const emptyForm = (): FormState => ({
  id: '',
  name: '',
  tagline: '',
  palette: 'tide',
  isPremium: false,
  isDefault: false,
  isActive: false,
})

function PlantsPage() {
  const qc = useQueryClient()
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(emptyForm())
  const [formError, setFormError] = useState<string | null>(null)
  const [listError, setListError] = useState<string | null>(null)

  const plants = useQuery({
    queryKey: ['plants'],
    queryFn: () => listPlants(),
  })

  const invalidate = () => qc.invalidateQueries({ queryKey: ['plants'] })

  const startCreate = () => {
    setEditingId(null)
    setFormError(null)
    setForm(emptyForm())
  }

  const startEdit = (p: Plant) => {
    setEditingId(p.id)
    setFormError(null)
    setForm({
      id: p.id,
      name: p.name,
      tagline: p.tagline,
      palette: p.palette,
      isPremium: p.isPremium,
      isDefault: p.isDefault,
      isActive: p.isActive,
    })
  }

  const save = useMutation({
    mutationFn: async () => {
      if (editingId) {
        await updatePlant(editingId, {
          name: form.name,
          tagline: form.tagline,
          palette: form.palette,
          isPremium: form.isPremium,
          isDefault: form.isDefault,
          isActive: form.isActive,
        })
      } else {
        await createPlant({
          id: form.id,
          name: form.name,
          tagline: form.tagline,
          palette: form.palette,
          isPremium: form.isPremium,
          isDefault: form.isDefault,
          isActive: form.isActive,
        })
      }
    },
    onSuccess: () => {
      setFormError(null)
      setEditingId(null)
      setForm(emptyForm())
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: (id: string) => deletePlant(id),
    onSuccess: () => {
      setListError(null)
      invalidate()
    },
    onError: (e) => setListError(apiErrorMessage(e)),
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderPlants(ids),
    onSuccess: invalidate,
  })

  const handleMove = (index: number, dir: -1 | 1) => {
    if (!plants.data) return
    const ids = moveItem(plants.data.map((p) => p.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    save.mutate()
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Mind Garden</h1>
          <div className="page-subtitle">
            Plants and the growth stages they pass through
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-title">{editingId ? 'Edit plant' : 'New plant'}</div>
        {formError && <div className="error-banner">{formError}</div>}
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            {!editingId && (
              <div className="field">
                <label>Id</label>
                <input
                  value={form.id}
                  onChange={(e) => setForm({ ...form, id: e.target.value })}
                  placeholder="oak"
                  required
                />
              </div>
            )}
            <div className="field">
              <label>Palette</label>
              <select
                value={form.palette}
                onChange={(e) => setForm({ ...form, palette: e.target.value as Palette })}
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
            <label>Name</label>
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              required
            />
          </div>
          <div className="field">
            <label>Tagline</label>
            <input
              value={form.tagline}
              onChange={(e) => setForm({ ...form, tagline: e.target.value })}
              required
            />
          </div>
          <div className="form-row">
            <div className="field checkbox-field">
              <input
                id="plantPremium"
                type="checkbox"
                checked={form.isPremium}
                onChange={(e) => setForm({ ...form, isPremium: e.target.checked })}
              />
              <label htmlFor="plantPremium">Premium</label>
            </div>
            <div className="field checkbox-field">
              <input
                id="plantDefault"
                type="checkbox"
                checked={form.isDefault}
                onChange={(e) => setForm({ ...form, isDefault: e.target.checked })}
              />
              <label htmlFor="plantDefault">Default</label>
            </div>
          </div>
          <div className="field checkbox-field">
            <input
              id="plantActive"
              type="checkbox"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
            />
            <label htmlFor="plantActive">Visible</label>
          </div>
          <div className="form-actions">
            <button className="btn" type="submit" disabled={save.isPending}>
              {editingId ? 'Save changes' : 'Create plant'}
            </button>
            {editingId && (
              <button type="button" className="btn btn-ghost" onClick={startCreate}>
                Cancel
              </button>
            )}
          </div>
        </form>
      </div>

      {plants.error && <div className="error-banner">{apiErrorMessage(plants.error)}</div>}
      {listError && <div className="error-banner">{listError}</div>}

      {plants.isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Palette</th>
                <th>Stages</th>
                <th>Flags</th>
                <th style={{ width: 320 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(plants.data ?? []).map((p, i) => (
                <tr key={p.id}>
                  <td>
                    <Link to={`/plants/${p.id}`} className="title-cell">
                      {p.name}
                    </Link>
                    <div className="subtitle-cell">{p.tagline}</div>
                  </td>
                  <td>
                    <PaletteSwatch palette={p.palette} />
                  </td>
                  <td className="muted">{p.stageCount ?? 0}</td>
                  <td>
                    <div className="row-actions">
                      {p.isPremium && <span className="badge badge-premium">Premium</span>}
                      {p.isDefault && <span className="badge">Default</span>}
                      <span className="badge">{p.isActive ? 'Visible' : 'Hidden'}</span>
                      <PendingBadge pending={p.pending} />
                    </div>
                  </td>
                  <td>
                    <div className="row-actions">
                      <button
                        className="btn btn-ghost btn-icon"
                        disabled={i === 0}
                        title="Move up"
                        onClick={() => handleMove(i, -1)}
                      >
                        ↑
                      </button>
                      <button
                        className="btn btn-ghost btn-icon"
                        disabled={i === plants.data!.length - 1}
                        title="Move down"
                        onClick={() => handleMove(i, 1)}
                      >
                        ↓
                      </button>
                      <Link className="btn btn-ghost btn-sm" to={`/plants/${p.id}`}>
                        Stages
                      </Link>
                      <button className="btn btn-ghost btn-sm" onClick={() => startEdit(p)}>
                        Edit
                      </button>
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => {
                          if (confirm(`Delete plant "${p.name}"?`)) remove.mutate(p.id)
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {plants.data && plants.data.length === 0 && (
                <tr>
                  <td colSpan={5} className="empty">
                    No plants yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default PlantsPage
