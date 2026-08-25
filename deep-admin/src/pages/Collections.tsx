import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createCollection,
  deleteCollection,
  listCategories,
  listCollections,
  reorderCollections,
  updateCollection,
  uploadMedia,
} from '../api/endpoints'
import { PALETTES, type Collection, type Palette } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PaletteSwatch } from '../components/PaletteSwatch'
import { MediaDropzone } from '../components/MediaDropzone'

type FormState = {
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl: string
  isPremium: boolean
}

const emptyForm = (categoryId: string): FormState => ({
  categoryId,
  title: '',
  subtitle: '',
  palette: 'tide',
  imageUrl: '',
  isPremium: false,
})

function CollectionsPage() {
  const qc = useQueryClient()
  const [filter, setFilter] = useState<string>('') // '' = all
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  const categories = useQuery({
    queryKey: ['categories'],
    queryFn: () => listCategories(),
  })

  const collections = useQuery({
    queryKey: ['collections', filter || undefined],
    queryFn: () => listCollections(filter || undefined),
  })

  const categoryName = useMemo(() => {
    const map = new Map<string, string>()
    categories.data?.forEach((c) => map.set(c.id, c.title))
    return map
  }, [categories.data])

  const defaultCategoryId = filter || categories.data?.[0]?.id || ''

  // Open the create form once categories are known.
  useEffect(() => {
    if (!form && !editingId && defaultCategoryId) {
      setForm(emptyForm(defaultCategoryId))
    }
  }, [defaultCategoryId, form, editingId])

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['collections'] })
    qc.invalidateQueries({ queryKey: ['categories'] })
  }

  const startCreate = () => {
    setEditingId(null)
    setFormError(null)
    setForm(emptyForm(defaultCategoryId))
  }

  const startEdit = (c: Collection) => {
    setEditingId(c.id)
    setFormError(null)
    setForm({
      categoryId: c.categoryId,
      title: c.title,
      subtitle: c.subtitle,
      palette: c.palette,
      imageUrl: c.imageUrl ?? '',
      isPremium: c.isPremium,
    })
  }

  const save = useMutation({
    mutationFn: async () => {
      if (!form) return
      const payload = {
        categoryId: form.categoryId,
        title: form.title,
        subtitle: form.subtitle,
        palette: form.palette,
        imageUrl: form.imageUrl.trim() ? form.imageUrl.trim() : undefined,
        isPremium: form.isPremium,
      }
      if (editingId) {
        await updateCollection(editingId, payload)
      } else {
        await createCollection(payload)
      }
    },
    onSuccess: () => {
      setFormError(null)
      setEditingId(null)
      setForm(emptyForm(defaultCategoryId))
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: (id: string) => deleteCollection(id),
    onSuccess: invalidate,
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderCollections(ids),
    onSuccess: invalidate,
  })

  const handleMove = (index: number, dir: -1 | 1) => {
    if (!collections.data) return
    const ids = moveItem(collections.data.map((c) => c.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    save.mutate()
  }

  const canReorder = filter !== '' // reorder only within a single category

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Collections</h1>
          <div className="page-subtitle">Sound collections grouped by category</div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-title">
          {editingId ? 'Edit collection' : 'New collection'}
        </div>
        {formError && <div className="error-banner">{formError}</div>}
        {form && (
          <form onSubmit={handleSubmit}>
            <div className="form-row">
              <div className="field">
                <label>Category</label>
                <select
                  value={form.categoryId}
                  onChange={(e) => setForm({ ...form, categoryId: e.target.value })}
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
                  value={form.palette}
                  onChange={(e) =>
                    setForm({ ...form, palette: e.target.value as Palette })
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
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                required
              />
            </div>
            <div className="field">
              <label>Subtitle</label>
              <input
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                required
              />
            </div>
            <MediaDropzone
              label="Cover image"
              kind="image"
              currentUrl={form.imageUrl || null}
              onUpload={async (file, onProgress) => {
                const media = await uploadMedia('image', file, onProgress)
                setForm((f) => (f ? { ...f, imageUrl: media.path } : f))
              }}
              onClear={() => setForm((f) => (f ? { ...f, imageUrl: '' } : f))}
              urlInput={{
                value: form.imageUrl,
                onChange: (v) => setForm((f) => (f ? { ...f, imageUrl: v } : f)),
                placeholder: 'https://…',
              }}
            />
            <div className="field checkbox-field">
              <input
                id="isPremium"
                type="checkbox"
                checked={form.isPremium}
                onChange={(e) => setForm({ ...form, isPremium: e.target.checked })}
              />
              <label htmlFor="isPremium">Premium</label>
            </div>
            <div className="form-actions">
              <button className="btn" type="submit" disabled={save.isPending}>
                {editingId ? 'Save changes' : 'Create collection'}
              </button>
              {editingId && (
                <button
                  type="button"
                  className="btn btn-ghost"
                  onClick={startCreate}
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        )}
      </div>

      <div className="filter-bar">
        <label className="muted">Filter by category</label>
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">All categories</option>
          {categories.data?.map((c) => (
            <option key={c.id} value={c.id}>
              {c.title}
            </option>
          ))}
        </select>
      </div>

      {collections.error && (
        <div className="error-banner">{apiErrorMessage(collections.error)}</div>
      )}

      {collections.isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Category</th>
                <th>Palette</th>
                <th>Tracks</th>
                <th>Premium</th>
                <th style={{ width: 300 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(collections.data ?? []).map((c, i) => (
                <tr key={c.id}>
                  <td>
                    <Link to={`/collections/${c.id}`} className="title-cell">
                      {c.title}
                    </Link>
                    <div className="subtitle-cell">{c.subtitle}</div>
                  </td>
                  <td className="muted">{categoryName.get(c.categoryId) ?? '—'}</td>
                  <td>
                    <PaletteSwatch palette={c.palette} />
                  </td>
                  <td className="muted">{c.trackCount}</td>
                  <td>
                    {c.isPremium ? (
                      <span className="badge badge-premium">Premium</span>
                    ) : (
                      <span className="muted">Free</span>
                    )}
                  </td>
                  <td>
                    <div className="row-actions">
                      <button
                        className="btn btn-ghost btn-icon"
                        disabled={!canReorder || i === 0}
                        title={canReorder ? 'Move up' : 'Filter by a category to reorder'}
                        onClick={() => handleMove(i, -1)}
                      >
                        ↑
                      </button>
                      <button
                        className="btn btn-ghost btn-icon"
                        disabled={!canReorder || i === collections.data!.length - 1}
                        title={canReorder ? 'Move down' : 'Filter by a category to reorder'}
                        onClick={() => handleMove(i, 1)}
                      >
                        ↓
                      </button>
                      <Link className="btn btn-ghost btn-sm" to={`/collections/${c.id}`}>
                        Tracks
                      </Link>
                      <button className="btn btn-ghost btn-sm" onClick={() => startEdit(c)}>
                        Edit
                      </button>
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => {
                          if (confirm(`Delete collection "${c.title}"?`)) remove.mutate(c.id)
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {collections.data && collections.data.length === 0 && (
                <tr>
                  <td colSpan={6} className="empty">
                    No collections in this view.
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

export default CollectionsPage
