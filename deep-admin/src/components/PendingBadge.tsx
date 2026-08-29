import type { PendingMarker } from '../api/types'
import { pendingLabel } from '../lib/pending'

/**
 * The Draft / Edited / Will delete pill. Renders nothing when the row matches
 * what the app is serving, so a clean table stays clean.
 */
export function PendingBadge({ pending }: { pending: PendingMarker | null }) {
  if (!pending) return null

  const variant =
    pending.op === 'DELETE' ? 'badge-deleting' : 'badge-pending'

  return (
    <span className={`badge ${variant}`} title={titleFor(pending)}>
      {pendingLabel(pending.op)}
    </span>
  )
}

function titleFor(pending: PendingMarker): string {
  const when = new Date(pending.stagedAt).toLocaleString()
  if (pending.op === 'DELETE') return `Deletion staged ${when}. Not yet published.`
  if (pending.op === 'CREATE') return `Created ${when}. Not yet visible in the app.`
  const fields = pending.changedFields.length
  return `${fields} ${fields === 1 ? 'field' : 'fields'} edited ${when}. Not yet published.`
}

