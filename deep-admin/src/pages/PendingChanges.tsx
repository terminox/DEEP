import { useMemo, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { discardChanges, publishChanges, validateChanges } from '../api/endpoints'
import { apiErrorMessage } from '../api/errors'
import {
  CHANGE_AREA_LABELS,
  type ChangeArea,
  type PendingChange,
} from '../api/types'
import {
  fieldLabel,
  formatValue,
  pendingLabel,
  usePendingChanges,
} from '../lib/pending'

const AREA_ORDER: ChangeArea[] = ['sound', 'garden', 'pause']

/**
 * The review screen: everything staged, what it will do, and the one button
 * that moves it. This is the page that makes the whole feature legible - if an
 * admin cannot see what publishing will change, staging has only added a step.
 */
function PendingChangesPage() {
  const qc = useQueryClient()
  const { data: changes, isLoading } = usePendingChanges()
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<string | null>(null)

  const grouped = useMemo(() => {
    const byArea = new Map<ChangeArea, PendingChange[]>()
    for (const change of changes ?? []) {
      const list = byArea.get(change.area) ?? []
      list.push(change)
      byArea.set(change.area, list)
    }
    return AREA_ORDER.filter((a) => byArea.has(a)).map((area) => ({
      area,
      changes: byArea.get(area)!,
    }))
  }, [changes])

  const toggle = (key: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  const toggleArea = (area: ChangeArea, on: boolean) => {
    const keys = grouped.find((g) => g.area === area)?.changes.map((c) => c.key) ?? []
    setSelected((prev) => {
      const next = new Set(prev)
      for (const key of keys) {
        if (on) next.add(key)
        else next.delete(key)
      }
      return next
    })
  }

  const settle = (message: string) => {
    setError(null)
    setResult(message)
    setSelected(new Set())
    // Content moved: nothing cached about it is trustworthy any more.
    qc.invalidateQueries()
  }

  const runPublish = useMutation({
    mutationFn: async (all: boolean) => {
      const selection = all ? ({ all: true } as const) : { refs: [...selected] }
      const report = await validateChanges(selection)
      if (report.blockers.length > 0) {
        throw new Error(report.blockers.join(' '))
      }

      const count = report.resolved.length
      const extra = report.addedByDependency.length
      const also = extra
        ? `\n\nIncluding ${extra} related ${
            extra === 1 ? 'change' : 'changes'
          } the selection depends on.`
        : ''
      const warn = report.warnings.length ? `\n\n${report.warnings.join('\n')}` : ''
      const ok = confirm(
        `Publish ${count} ${count === 1 ? 'change' : 'changes'} to the app now?` +
          `${also}${warn}\n\nThis cannot be undone.`
      )
      if (!ok) return null
      return publishChanges({ refs: report.resolved })
    },
    onSuccess: (res) => {
      if (!res) return
      settle(
        `Published ${res.published} ${res.published === 1 ? 'change' : 'changes'}. The app is now serving them.`
      )
    },
    onError: (e) => {
      setResult(null)
      setError(apiErrorMessage(e))
    },
  })

  const runDiscard = useMutation({
    mutationFn: async (all: boolean) => {
      const count = all ? (changes?.length ?? 0) : selected.size
      const ok = confirm(
        `Discard ${count} unpublished ${count === 1 ? 'change' : 'changes'}? They cannot be recovered.`
      )
      if (!ok) return null
      return discardChanges(all ? { all: true } : { refs: [...selected] })
    },
    onSuccess: (res) => {
      if (!res) return
      settle(`Discarded ${res.discarded} ${res.discarded === 1 ? 'change' : 'changes'}.`)
    },
    onError: (e) => {
      setResult(null)
      setError(apiErrorMessage(e))
    },
  })

  const busy = runPublish.isPending || runDiscard.isPending
  const total = changes?.length ?? 0

  if (isLoading) return <div className="state">Loading…</div>

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Pending changes</h1>
          <div className="page-subtitle">
            {total === 0
              ? 'Everything is published. The app is showing exactly what you see in the admin.'
              : `${total} ${total === 1 ? 'change is' : 'changes are'} staged. The app is still showing the previous version until you publish.`}
          </div>
        </div>
        {total > 0 && (
          <div className="row-actions">
            <button
              className="btn"
              onClick={() => runPublish.mutate(true)}
              disabled={busy}
            >
              {runPublish.isPending ? 'Publishing…' : 'Publish all'}
            </button>
            <button
              className="btn btn-ghost btn-danger"
              onClick={() => runDiscard.mutate(true)}
              disabled={busy}
            >
              Discard all
            </button>
          </div>
        )}
      </div>

      {error && <div className="error-banner">{error}</div>}
      {result && <div className="success-banner">{result}</div>}

      {total === 0 ? (
        <div className="panel">
          <div className="empty">Nothing waiting to be published.</div>
        </div>
      ) : (
        <>
          {selected.size > 0 && (
            <div className="panel selection-bar">
              <div>
                {selected.size} selected. Publishing pulls in anything the
                selection depends on.
              </div>
              <div className="row-actions">
                <button
                  className="btn btn-sm"
                  onClick={() => runPublish.mutate(false)}
                  disabled={busy}
                >
                  Publish selected
                </button>
                <button
                  className="btn btn-sm btn-ghost btn-danger"
                  onClick={() => runDiscard.mutate(false)}
                  disabled={busy}
                >
                  Discard selected
                </button>
                <button
                  className="btn btn-sm btn-ghost"
                  onClick={() => setSelected(new Set())}
                  disabled={busy}
                >
                  Clear
                </button>
              </div>
            </div>
          )}

          {grouped.map(({ area, changes: areaChanges }) => {
            const allOn = areaChanges.every((c) => selected.has(c.key))
            return (
              <div className="panel" key={area}>
                <div className="section-header">
                  <div className="section-title">{CHANGE_AREA_LABELS[area]}</div>
                  <button
                    className="btn btn-sm btn-ghost"
                    onClick={() => toggleArea(area, !allOn)}
                  >
                    {allOn ? 'Deselect all' : 'Select all'}
                  </button>
                </div>

                <div className="stack">
                  {areaChanges.map((change) => (
                    <ChangeRow
                      key={change.key}
                      change={change}
                      checked={selected.has(change.key)}
                      onToggle={() => toggle(change.key)}
                    />
                  ))}
                </div>
              </div>
            )
          })}
        </>
      )}
    </>
  )
}

function ChangeRow({
  change,
  checked,
  onToggle,
}: {
  change: PendingChange
  checked: boolean
  onToggle: () => void
}) {
  return (
    <div className="change-row">
      <input
        type="checkbox"
        checked={checked}
        onChange={onToggle}
        aria-label={`Select ${change.noun} ${change.label}`}
      />
      <div className="change-body">
        <div className="change-head">
          <span
            className={`badge ${
              change.op === 'DELETE' ? 'badge-deleting' : 'badge-pending'
            }`}
          >
            {pendingLabel(change.op)}
          </span>
          <span className="change-noun">{change.noun}</span>
          <strong className="change-label">{change.label || '(untitled)'}</strong>
          {change.parentLabel && (
            <span className="muted">in {change.parentLabel}</span>
          )}
        </div>

        {change.op === 'DELETE' && change.cascade.length > 0 && (
          <div className="warning-banner">
            Also removes{' '}
            {change.cascade
              .map((c) => `${c.count} ${c.noun}${c.count === 1 ? '' : 's'}`)
              .join(', ')}
            .
          </div>
        )}

        {change.fields.length > 0 && (
          <table className="diff-table">
            <tbody>
              {change.fields.map((f) => (
                <tr key={f.field}>
                  <td className="diff-field">{fieldLabel(f.field)}</td>
                  <td className="diff-before">{formatValue(f.before)}</td>
                  <td className="diff-arrow">→</td>
                  <td className="diff-after">{formatValue(f.after)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        <div className="change-meta muted">
          {change.authorName} · {new Date(change.stagedAt).toLocaleString()}
        </div>
      </div>
    </div>
  )
}

export default PendingChangesPage
