import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  getPauseStats,
  listPeaceMessages,
  updatePeaceMessageStatus,
} from '../api/endpoints'
import {
  PEACE_MESSAGE_STATUSES,
  type AdminPeaceMessage,
  type PeaceMessageStatus,
} from '../api/types'
import { apiErrorMessage } from '../api/errors'

// "calm ×12, love ×5, hope ×2" for the three most common entries.
function topCounts(counts: Record<string, number>, limit = 3): string {
  const entries = Object.entries(counts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, limit)
  if (entries.length === 0) return '—'
  return entries.map(([key, count]) => `${key} ×${count}`).join(', ')
}

function StatsPanel() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['pause-stats', 7],
    queryFn: () => getPauseStats(7),
  })

  const dates = Object.keys(data?.byDate ?? {}).sort((a, b) =>
    b.localeCompare(a)
  )

  return (
    <div className="panel">
      <div className="panel-title">Reflections — last 7 days</div>
      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}
      {isLoading ? (
        <div className="state">Loading…</div>
      ) : dates.length === 0 ? (
        <div className="empty">No reflections in the last 7 days.</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Total</th>
                <th>Top intentions</th>
                <th>Top moods</th>
              </tr>
            </thead>
            <tbody>
              {dates.map((date) => {
                const day = data!.byDate[date]
                return (
                  <tr key={date}>
                    <td className="mono">{date}</td>
                    <td className="title-cell">{day.total}</td>
                    <td className="muted">{topCounts(day.intentions)}</td>
                    <td className="muted">{topCounts(day.moods)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function MessageRow({ message }: { message: AdminPeaceMessage }) {
  const qc = useQueryClient()
  const [error, setError] = useState<string | null>(null)

  const toggle = useMutation({
    mutationFn: () =>
      updatePeaceMessageStatus(
        message.id,
        message.status === 'PUBLISHED' ? 'HIDDEN' : 'PUBLISHED'
      ),
    onSuccess: () => {
      setError(null)
      qc.invalidateQueries({ queryKey: ['peace-messages'] })
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <tr>
      <td>
        <span className="title-cell">{message.displayName}</span>
        {message.countryISO && (
          <div className="subtitle-cell">{message.countryISO}</div>
        )}
      </td>
      <td>
        {message.text}
        {error && <div className="error-banner" style={{ marginTop: 8 }}>{error}</div>}
      </td>
      <td>
        {message.status === 'PUBLISHED' ? (
          <span className="badge badge-role">Published</span>
        ) : (
          <span className="muted">Hidden</span>
        )}
      </td>
      <td className="mono">{message.pauseDate}</td>
      <td className="muted">
        {new Date(message.createdAt).toLocaleString()}
      </td>
      <td>
        <div className="row-actions">
          <button
            className={`btn btn-sm ${message.status === 'PUBLISHED' ? 'btn-danger' : 'btn-ghost'}`}
            onClick={() => toggle.mutate()}
            disabled={toggle.isPending}
          >
            {message.status === 'PUBLISHED' ? 'Hide' : 'Publish'}
          </button>
        </div>
      </td>
    </tr>
  )
}

function PeaceMessagesPage() {
  const [status, setStatus] = useState<PeaceMessageStatus | ''>('')
  const [pauseDate, setPauseDate] = useState('')

  const { data, isLoading, error } = useQuery({
    queryKey: ['peace-messages', status, pauseDate],
    queryFn: () =>
      listPeaceMessages({
        status: status || undefined,
        pauseDate: pauseDate || undefined,
      }),
  })

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Peace Messages</h1>
          <div className="page-subtitle">
            Moderate messages shared during the Global Pause feedback phase
          </div>
        </div>
      </div>

      <StatsPanel />

      <div className="filter-bar">
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as PeaceMessageStatus | '')}
        >
          <option value="">All statuses</option>
          {PEACE_MESSAGE_STATUSES.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
        <input
          type="date"
          value={pauseDate}
          onChange={(e) => setPauseDate(e.target.value)}
          style={{ width: 'auto' }}
        />
        {(status || pauseDate) && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => {
              setStatus('')
              setPauseDate('')
            }}
          >
            Clear filters
          </button>
        )}
      </div>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>From</th>
                <th>Message</th>
                <th>Status</th>
                <th>Pause date</th>
                <th>Posted</th>
                <th style={{ width: 120 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((m) => (
                <MessageRow key={m.id} message={m} />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={6} className="empty">
                    No peace messages match these filters.
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

export default PeaceMessagesPage
