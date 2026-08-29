import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { discardChanges, publishChanges, validateChanges } from '../api/endpoints'
import { apiErrorMessage } from '../api/errors'
import { usePendingChanges, refsUnder } from '../lib/pending'

/**
 * The per-record publish path: a strip under the page header saying this record
 * has unpublished changes, with the two actions that resolve it.
 *
 * Publishing one record pulls in whatever it depends on (a track's collection,
 * if that collection is itself still a draft) and everything staged underneath
 * it, so the app never receives half a change. The confirm names exactly what
 * will happen, because this is the step that is not reversible.
 */
export function PendingBar({ entityKey }: { entityKey: string }) {
  const qc = useQueryClient()
  const [error, setError] = useState<string | null>(null)
  const { data: changes } = usePendingChanges()

  const staged = changes?.some((c) => c.key === entityKey) ?? false
  const refs = changes ? refsUnder(changes, entityKey) : []

  const refresh = () => {
    setError(null)
    // Publishing rewrites live content, so nothing cached is trustworthy.
    qc.invalidateQueries()
  }

  const publish = useMutation({
    mutationFn: async () => {
      const report = await validateChanges({ refs })
      if (report.blockers.length > 0) {
        throw new Error(report.blockers.join(' '))
      }
      const extra = report.addedByDependency.length
      const also = extra
        ? `\n\nThis will also publish ${extra} related ${
            extra === 1 ? 'change' : 'changes'
          } it depends on.`
        : ''
      const warn = report.warnings.length
        ? `\n\n${report.warnings.join('\n')}`
        : ''
      if (!confirm(`Publish these changes to the app now?${also}${warn}`)) {
        return null
      }
      return publishChanges({ refs: report.resolved })
    },
    onSuccess: refresh,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const throwAway = useMutation({
    mutationFn: async () => {
      if (!confirm('Discard these unpublished changes? They cannot be recovered.')) {
        return null
      }
      return discardChanges({ refs })
    },
    onSuccess: refresh,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  // After the hooks, never before them: this component is rendered
  // unconditionally by pages that may or may not have a staged record.
  if (!staged) return null

  const busy = publish.isPending || throwAway.isPending
  const extra = refs.length - 1

  return (
    <div className="warning-banner pending-bar">
      <div className="pending-bar-text">
        <strong>Unpublished changes.</strong> The app is still showing the
        previous version
        {extra > 0
          ? `, and ${extra} related ${extra === 1 ? 'change is' : 'changes are'} staged underneath this one`
          : ''}
        . <Link to="/changes">Review all pending changes</Link>
      </div>
      <div className="pending-bar-actions">
        <button
          className="btn btn-sm"
          onClick={() => publish.mutate()}
          disabled={busy}
        >
          {publish.isPending ? 'Publishing…' : 'Publish'}
        </button>
        <button
          className="btn btn-sm btn-ghost"
          onClick={() => throwAway.mutate()}
          disabled={busy}
        >
          Discard
        </button>
      </div>
      {error && <div className="pending-bar-error">{error}</div>}
    </div>
  )
}

