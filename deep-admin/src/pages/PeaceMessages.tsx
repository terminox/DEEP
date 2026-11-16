import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  getPauseStats,
  listPeaceMessages,
  setUserSuspended,
  updatePeaceMessageStatus,
} from '../api/endpoints'
import {
  PEACE_MESSAGE_STATUSES,
  REPORT_REASON_LABELS,
  type AdminPeaceMessage,
  type PeaceMessageStatus,
  type ReportReason,
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

// One line per reason given ("Offensive 2"), in the order the app offers them.
function ReasonLines({ reasons }: { reasons: Record<ReportReason, number> }) {
  return (Object.keys(REPORT_REASON_LABELS) as ReportReason[])
    .filter((reason) => reasons[reason] > 0)
    .map((reason) => (
      <div key={reason} className="subtitle-cell nowrap">
        {REPORT_REASON_LABELS[reason]} {reasons[reason]}
      </div>
    ))
}

function MessageRow({ message }: { message: AdminPeaceMessage }) {
  const qc = useQueryClient()
  const [error, setError] = useState<string | null>(null)
  const userId = message.userId

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

  // The same suspension as on the Users page, reached from the message so the
  // admin acts on this author rather than someone sharing their display name.
  const suspension = useMutation({
    mutationFn: (suspended: boolean) => setUserSuspended(userId!, suspended),
    onSuccess: () => {
      setError(null)
      qc.invalidateQueries({ queryKey: ['peace-messages'] })
      qc.invalidateQueries({ queryKey: ['users'] })
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const toggleSuspension = () => {
    if (
      !message.authorSuspended &&
      !confirm(
        `Suspend ${message.displayName}? They won't be able to share peace messages, and the ones they shared will be hidden from everyone.`
      )
    ) {
      return
    }
    suspension.mutate(!message.authorSuspended)
  }

  return (
    <tr>
      <td>
        <span className="title-cell">{message.displayName}</span>
        {message.countryISO && (
          <div className="subtitle-cell">{message.countryISO}</div>
        )}
        {message.authorSuspended && (
          <div>
            <span className="badge badge-suspended">Suspended</span>
          </div>
        )}
      </td>
      <td>
        {message.text}
        {message.intention && (
          <div className="subtitle-cell">{message.intention}</div>
        )}
        {error && <div className="error-banner">{error}</div>}
      </td>
      <td>
        {message.status === 'PUBLISHED' ? (
          <span className="badge badge-role">Published</span>
        ) : (
          <span className="muted">Hidden</span>
        )}
      </td>
      <td>
        {message.reportCount > 0 ? (
          <>
            <span className="badge badge-reported">{message.reportCount}</span>
            <ReasonLines reasons={message.reasons} />
          </>
        ) : message.totalReportCount > 0 ? (
          <span className="muted">{message.totalReportCount} reviewed</span>
        ) : (
          <span className="muted">—</span>
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
          {userId && (
            <button
              className="btn btn-sm btn-ghost"
              onClick={toggleSuspension}
              disabled={suspension.isPending}
            >
              {message.authorSuspended ? 'Restore author' : 'Suspend author'}
            </button>
          )}
        </div>
      </td>
    </tr>
  )
}

function PeaceMessagesPage() {
  const [status, setStatus] = useState<PeaceMessageStatus | ''>('')
  const [pauseDate, setPauseDate] = useState('')
  // The sidebar's report badge links here with ?reported=1.
  const [searchParams, setSearchParams] = useSearchParams()
  const reportedOnly = searchParams.get('reported') === '1'
  const setReportedOnly = (on: boolean) =>
    setSearchParams(on ? { reported: '1' } : {}, { replace: true })

  const { data, isLoading, error } = useQuery({
    queryKey: ['peace-messages', status, pauseDate, reportedOnly],
    queryFn: () =>
      listPeaceMessages({
        status: status || undefined,
        pauseDate: pauseDate || undefined,
        reported: reportedOnly || undefined,
      }),
  })

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Peace messages</h1>
          <div className="page-subtitle">
            Moderate messages shared during the Global Pause feedback phase.
            Members' reports hide a message automatically once enough of them
            agree; Publish restores it. Publish or Hide settles the reports so
            far, so only new reports count toward hiding it again. Each report
            shows the reason the member chose, and Suspend author stops that
            member sharing messages at all.
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
        <select
          value={reportedOnly ? 'reported' : ''}
          onChange={(e) => setReportedOnly(e.target.value === 'reported')}
        >
          <option value="">All messages</option>
          <option value="reported">Reported</option>
        </select>
        <input
          type="date"
          value={pauseDate}
          onChange={(e) => setPauseDate(e.target.value)}
          style={{ width: 'auto' }}
        />
        {(status || pauseDate || reportedOnly) && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => {
              setStatus('')
              setPauseDate('')
              setReportedOnly(false)
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
                <th>Reports</th>
                <th>Pause date</th>
                <th>Posted</th>
                <th style={{ width: 220 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((m) => (
                <MessageRow key={m.id} message={m} />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={7} className="empty">
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
