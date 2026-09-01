import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createCategory,
  deleteCategory,
  listCategories,
  reorderCategories,
  updateCategory,
} from '../api/endpoints'
import type { Category } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { PendingBadge } from '../components/PendingBadge'

function CategoryRow({
  category,
  index,
  count,
  onMove,
}: {
  category: Category
  index: number
  count: number
  onMove: (index: number, dir: -1 | 1) => void
}) {
  const qc = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [title, setTitle] = useState(category.title)
  const [slug, setSlug] = useState(category.slug)
  const [error, setError] = useState<string | null>(null)

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['categories'] })
  }

  const save = useMutation({
    mutationFn: () => updateCategory(category.id, { title, slug }),
    onSuccess: () => {
      setEditing(false)
      setError(null)
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: () => deleteCategory(category.id),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  // Visibility is not the publish workflow: it pulls LIVE content off the app
  // without deleting it. Toggling it is itself a staged change.
  const toggleVisible = useMutation({
    mutationFn: () => updateCategory(category.id, { isActive: !category.isActive }),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <tr>
      <td>
        {editing ? (
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Title"
          />
        ) : (
          <span className="title-cell-row">
            <Link to={`/categories/${category.id}`} className="title-cell">
              {category.title}
            </Link>
            <PendingBadge pending={category.pending} />
          </span>
        )}
        {error && <div className="error-banner">{error}</div>}
      </td>
      <td className="mono">
        {editing ? (
          <input value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="slug" />
        ) : (
          category.slug
        )}
      </td>
      <td className="muted">{category.collectionCount}</td>
      <td>
        {category.isActive ? (
          <span className="badge badge-role">Visible</span>
        ) : (
          <span className="muted">Hidden</span>
        )}
      </td>
      <td>
        <div className="row-actions">
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === 0}
            onClick={() => onMove(index, -1)}
            title="Move up"
          >
            ↑
          </button>
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === count - 1}
            onClick={() => onMove(index, 1)}
            title="Move down"
          >
            ↓
          </button>
          {editing ? (
            <>
              <button
                className="btn btn-sm"
                onClick={() => save.mutate()}
                disabled={save.isPending}
              >
                Save
              </button>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => {
                  setEditing(false)
                  setTitle(category.title)
                  setSlug(category.slug)
                  setError(null)
                }}
              >
                Cancel
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setEditing(true)}>
              Edit
            </button>
          )}
          <button
            className={`btn btn-sm ${category.isActive ? 'btn-ghost' : ''}`}
            onClick={() => toggleVisible.mutate()}
            disabled={toggleVisible.isPending}
            title={
              category.isActive
                ? 'Stage hiding this from the app'
                : 'Stage showing this in the app'
            }
          >
            {category.isActive ? 'Hide' : 'Show'}
          </button>
          <button
            className="btn btn-danger btn-sm"
            onClick={() => {
              if (
                confirm(
                  `Stage deletion of category "${category.title}"?\n\nIt stays live in the app until you publish the change.`
                )
              )
                remove.mutate()
            }}
            disabled={remove.isPending}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  )
}

function CategoriesPage() {
  const qc = useQueryClient()
  const { data, isLoading, error } = useQuery({
    queryKey: ['categories'],
    queryFn: () => listCategories(),
  })

  const [slug, setSlug] = useState('')
  const [title, setTitle] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const invalidate = () => qc.invalidateQueries({ queryKey: ['categories'] })

  const create = useMutation({
    mutationFn: () => createCategory({ slug, title }),
    onSuccess: () => {
      setSlug('')
      setTitle('')
      setFormError(null)
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderCategories(ids),
    onSuccess: invalidate,
  })

  const handleCreate = (e: FormEvent) => {
    e.preventDefault()
    create.mutate()
  }

  const handleMove = (index: number, dir: -1 | 1) => {
    if (!data) return
    const ids = moveItem(data.map((c) => c.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Categories</h1>
          <div className="page-subtitle">
            Deep Sound shelves, and the Explore grid on Home
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-title">New category</div>
        {formError && <div className="error-banner">{formError}</div>}
        <form className="inline-form" onSubmit={handleCreate}>
          <div className="field">
            <label>Slug</label>
            <input value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="calm" required />
          </div>
          <div className="field">
            <label>Title</label>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Calm" required />
          </div>
          <button className="btn" type="submit" disabled={create.isPending}>
            Add category
          </button>
          <div className="form-hint muted">
            New categories are staged — publish to make them visible in the app.
          </div>
        </form>
      </div>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Slug</th>
                <th>Collections</th>
                <th>Visible</th>
                <th style={{ width: 400 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((c, i) => (
                <CategoryRow
                  key={c.id}
                  category={c}
                  index={i}
                  count={data!.length}
                  onMove={handleMove}
                />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={5} className="empty">
                    No categories yet.
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

export default CategoriesPage
