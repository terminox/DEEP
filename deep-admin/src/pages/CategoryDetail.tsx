import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
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
import { PendingBar } from '../components/PendingBar'
import { PendingBadge } from '../components/PendingBadge'
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

function CategoryDetailPage() {
  const { id = '' } = useParams()
  const qc = useQueryClient()

  const categories = useQuery({
    queryKey: ['categories'],
    queryFn: () => listCategories(),
  })

  const collections = useQuery({
    queryKey: ['collections', id],
    queryFn: () => listCollections(id),
    enabled: !!id,
  })

  const category = useMemo(
    () => categories.data?.find((c) => c.id === id),
    [categories.data, id]
  )

  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(emptyForm(id))
  const [formError, setFormError] = useState<string | null>(null)

  // Keep the create form pinned to this category as the route changes.
  useEffect(() => {
    if (!editingId) setForm(emptyForm(id))
  }, [id, editingId])

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['collections'] })
    qc.invalidateQueries({ queryKey: ['categories'] })
  }

  const startCreate = () => {
    setEditingId(null)
    setFormError(null)
    setForm(emptyForm(id))
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
      const payload = {
        categoryId: form.categoryId,
        title: form.title,
        subtitle: form.subtitle,
        palette: form.palette,
        imageUrl: form.imageUrl.trim() ? form.imageUrl.trim() : undefined,
        isPremium: form.isPremium,
      }
      if (editingId) await updateCollection(editingId, payload)
      else await createCollection(payload)
    },
    onSuccess: () => {
      setFormError(null)
      setEditingId(null)
      setForm(emptyForm(id))
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: (cid: string) => deleteCollection(cid),
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

  return (
    <div>
      <Link to="/categories" className="back-link">
        ← Back to categories
      </Link>

      <div className="page-header">
        <div>
          <h1>{category?.title ?? 'Category'}</h1>
          <div className="page-subtitle">
            {category ? `${category.collectionCount} collections · ` : ''}
            Collections in this category
          </div>
        </div>
      </div>

      {id && <PendingBar entityKey={`SOUND_CATEGORY:${id}`} />}

      <div className="panel">
        <div className="panel-title">
          {editingId ? 'Edit collection' : 'New collection'}
        </div>
        {formError && <div className="error-banner">{formError}</div>}
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
              setForm((f) => ({ ...f, imageUrl: media.path }))
            }}
            onClear={() => setForm((f) => ({ ...f, imageUrl: '' }))}
            urlInput={{
              value: form.imageUrl,
              onChange: (v) => setForm((f) => ({ ...f, imageUrl: v })),
              placeholder: 'https://…',
            }}
          />
          <div className="field checkbox-field">
            <input
              id="catColPremium"
              type="checkbox"
              checked={form.isPremium}
              onChange={(e) => setForm({ ...form, isPremium: e.target.checked })}
            />
            <label htmlFor="catColPremium">Premium</label>
          </div>
          <div className="form-actions">
            <button className="btn" type="submit" disabled={save.isPending}>
              {editingId ? 'Save changes' : 'Create collection'}
            </button>
            {editingId && (
              <button type="button" className="btn btn-ghost" onClick={startCreate}>
                Cancel
              </button>
            )}
          </div>
        </form>
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
                    <PendingBadge pending={c.pending} />
                    {!c.isActive && <span className="badge">Hidden</span>}
                    <Link to={`/collections/${c.id}`} className="title-cell">
                      {c.title}
                    </Link>
                    <div className="subtitle-cell">{c.subtitle}</div>
                  </td>
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
                        disabled={i === 0}
                        title="Move up"
                        onClick={() => handleMove(i, -1)}
                      >
                        ↑
                      </button>
                      <button
                        className="btn btn-ghost btn-icon"
                        disabled={i === collections.data!.length - 1}
                        title="Move down"
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
                  <td colSpan={5} className="empty">
                    No collections in this category yet.
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

export default CategoryDetailPage
