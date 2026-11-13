import { useState, type MouseEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getUserMembership, listUsers, setUserSuspended } from '../api/endpoints'
import { apiErrorMessage } from '../api/errors'
import type { AdminUser, Membership } from '../api/types'

const formatTime = (iso: string | null) => (iso ? new Date(iso).toLocaleString() : '—')
const yesNo = (value: boolean) => (value ? 'Yes' : 'No')

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="fact">
      <div className="fact-label">{label}</div>
      <div className="fact-value">{value}</div>
    </div>
  )
}

function MembershipFacts({ membership }: { membership: Membership }) {
  const sub = membership.subscription
  if (!sub) {
    return <div className="muted">No DEEP Premium record — this person has never subscribed.</div>
  }
  return (
    <div className="fact-grid">
      <Fact label="Product" value={sub.productId} />
      <Fact label="Store" value={sub.store} />
      <Fact label="Environment" value={sub.environment} />
      <Fact label="Period type" value={sub.periodType} />
      <Fact label="Expires" value={sub.expiresAt ? formatTime(sub.expiresAt) : 'Never'} />
      <Fact label="Will renew" value={yesNo(sub.willRenew)} />
      <Fact
        label="Grace period"
        value={
          membership.inGracePeriod
            ? `Until ${formatTime(sub.gracePeriodExpiresAt)}`
            : sub.gracePeriodExpiresAt
              ? `Ended ${formatTime(sub.gracePeriodExpiresAt)}`
              : 'No'
        }
      />
      <Fact label="Revoked" value={sub.revokedAt ? formatTime(sub.revokedAt) : 'No'} />
      <Fact label="Last event" value={formatTime(sub.lastEventAt)} />
    </div>
  )
}

function MembershipPanel({ user, onClose }: { user: AdminUser; onClose: () => void }) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['users', user.id, 'membership'],
    queryFn: () => getUserMembership(user.id),
  })

  return (
    <div className="panel">
      <div className="row-between membership-head">
        <div>
          <div className="panel-title membership-title">{user.displayName}</div>
          <div className="muted">{user.email}</div>
        </div>
        <button type="button" className="btn btn-ghost btn-sm" onClick={onClose}>
          Close
        </button>
      </div>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading || !data ? (
        !error && <div className="state">Loading…</div>
      ) : (
        <div className="stack">
          <div>
            <span className="fact-label">DEEP Premium</span>{' '}
            {data.active ? (
              <span className="badge badge-premium">Active</span>
            ) : (
              <span className="badge">Not active</span>
            )}
          </div>

          <MembershipFacts membership={data} />

          <div>
            <div className="section-title membership-events-title">Recent RevenueCat events</div>
            {data.events.length === 0 ? (
              <div className="muted">No events received for this person.</div>
            ) : (
              <div className="event-list">
                {data.events.map((e) => (
                  <div key={e.id} className="event-row">
                    <span className="event-type">{e.type}</span>
                    <span className="badge">{e.environment}</span>
                    <span className="badge badge-role">{e.outcome}</span>
                    <span className="muted">{formatTime(e.eventAt)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// Suspension closes peace messages only: the member can't post, and theirs
// leave every public feed until restored. Nothing else about the account changes.
function SuspensionCell({ user }: { user: AdminUser }) {
  const qc = useQueryClient()
  const [error, setError] = useState<string | null>(null)
  const suspended = user.suspendedAt !== null

  const toggle = useMutation({
    mutationFn: () => setUserSuspended(user.id, !suspended),
    onSuccess: () => {
      setError(null)
      qc.invalidateQueries({ queryKey: ['users'] })
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const onClick = (e: MouseEvent) => {
    // The row itself opens the membership panel.
    e.stopPropagation()
    if (
      !suspended &&
      !confirm(
        `Suspend ${user.displayName}? They won't be able to share peace messages, and the ones they shared will be hidden from everyone.`
      )
    ) {
      return
    }
    toggle.mutate()
  }

  return (
    <td onKeyDown={(e) => e.stopPropagation()}>
      <div className="row-actions">
        {suspended && (
          <span className="badge badge-suspended" title={formatTime(user.suspendedAt)}>
            Suspended
          </span>
        )}
        <button
          type="button"
          className={`btn btn-sm ${suspended ? 'btn-ghost' : 'btn-danger'}`}
          onClick={onClick}
          disabled={toggle.isPending}
        >
          {suspended ? 'Restore' : 'Suspend'}
        </button>
      </div>
      {error && <div className="error-banner">{error}</div>}
    </td>
  )
}

function UsersPage() {
  const [selected, setSelected] = useState<AdminUser | null>(null)
  const { data, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: () => listUsers(),
  })

  const toggle = (u: AdminUser) => setSelected((cur) => (cur?.id === u.id ? null : u))

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Users</h1>
          <div className="page-subtitle">
            App accounts. Select one to see their DEEP Premium membership. Suspend stops a
            member sharing peace messages and hides the ones they shared.
          </div>
        </div>
      </div>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {selected && (
        <MembershipPanel key={selected.id} user={selected} onClose={() => setSelected(null)} />
      )}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Created</th>
                <th>Peace messages</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((u) => (
                <tr
                  key={u.id}
                  className={`row-clickable${selected?.id === u.id ? ' row-selected' : ''}`}
                  tabIndex={0}
                  aria-selected={selected?.id === u.id}
                  onClick={() => toggle(u)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault()
                      toggle(u)
                    }
                  }}
                >
                  <td className="title-cell">{u.displayName}</td>
                  <td>{u.email}</td>
                  <td>
                    <span className="badge badge-role">{u.role}</span>
                  </td>
                  <td className="muted">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </td>
                  <SuspensionCell user={u} />
                </tr>
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={5} className="empty">
                    No users yet.
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

export default UsersPage
