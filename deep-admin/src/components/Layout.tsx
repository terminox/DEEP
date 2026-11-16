import { useEffect } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { clearSession } from '../auth/session'
import { usePendingCount } from '../lib/pending'
import { getPeaceMessageReviewCount } from '../api/endpoints'
import { CHANGE_AREA_LABELS } from '../api/types'

type NavItem = {
  to: string
  label: string
  end?: boolean
  spaced?: boolean
  // Shows how many reported messages await a decision, and links to that queue.
  reports?: boolean
}

type NavEntry =
  | ({ kind: 'link' } & NavItem)
  | { kind: 'group'; title: string; items: NavItem[] }

// The sidebar is organised the way the app is, and takes the feature names
// from the same map the pending-changes screen groups by, so the two can never
// drift apart. Mind Garden is a whole feature with a single screen, so it
// stands on its own rather than as a heading wrapping one child.
const navEntries: NavEntry[] = [
  { kind: 'link', to: '/', label: 'Dashboard', end: true },
  {
    kind: 'group',
    title: CHANGE_AREA_LABELS.sound,
    items: [
      { to: '/categories', label: 'Categories' },
      { to: '/collections', label: 'Collections' },
    ],
  },
  { kind: 'link', to: '/plants', label: CHANGE_AREA_LABELS.garden, spaced: true },
  {
    kind: 'group',
    title: CHANGE_AREA_LABELS.pause,
    items: [
      { to: '/pause', label: 'Schedule' },
      { to: '/peace-messages', label: 'Peace messages', reports: true },
    ],
  },
  { kind: 'link', to: '/users', label: 'Users', spaced: true },
]

function linkClass(item: NavItem) {
  return ({ isActive }: { isActive: boolean }) =>
    `nav-link${item.spaced ? ' nav-link-spaced' : ''}${
      isActive ? ' nav-link-active' : ''
    }`
}

function Layout() {
  const navigate = useNavigate()
  // Shown on every page on purpose: staged work that nobody remembers to
  // publish is the one way this feature can quietly make things worse.
  const { data: pendingCount } = usePendingCount()
  // Reported messages hide themselves at the threshold, so without this badge
  // nobody would know they wait. Under ['peace-messages'], so every decision
  // on that page refreshes it.
  const { data: reviewCount } = useQuery({
    queryKey: ['peace-messages', 'review-count'],
    queryFn: getPeaceMessageReviewCount,
    refetchInterval: 60_000,
  })

  const handleLogout = () => {
    clearSession()
    navigate('/login', { replace: true })
  }

  useEffect(() => {
    // Without this, missing a dropzone by a few pixels makes the browser
    // navigate away from the admin and silently discard unsaved form state.
    const swallow = (e: DragEvent) => e.preventDefault()
    window.addEventListener('dragover', swallow)
    window.addEventListener('drop', swallow)
    return () => {
      window.removeEventListener('dragover', swallow)
      window.removeEventListener('drop', swallow)
    }
  }, [])

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-dot" />
          DEEP Admin
        </div>
        <nav className="nav-links">
          {navEntries.map((entry) =>
            entry.kind === 'group' ? (
              <div className="nav-group" key={entry.title}>
                <div className="nav-group-title">{entry.title}</div>
                {entry.items.map((item) =>
                  item.reports && reviewCount ? (
                    <NavLink
                      key={item.to}
                      to={`${item.to}?reported=1`}
                      className={({ isActive }) =>
                        `${linkClass(item)({ isActive })} nav-link-counted`
                      }
                      title="Reported messages awaiting a decision"
                    >
                      {item.label}
                      <span className="nav-count nav-count-alert">{reviewCount}</span>
                    </NavLink>
                  ) : (
                    <NavLink key={item.to} to={item.to} className={linkClass(item)}>
                      {item.label}
                    </NavLink>
                  ),
                )}
              </div>
            ) : (
              <NavLink
                key={entry.to}
                to={entry.to}
                end={entry.end}
                className={linkClass(entry)}
              >
                {entry.label}
              </NavLink>
            ),
          )}

          <NavLink
            to="/changes"
            className={({ isActive }) =>
              `nav-link nav-link-changes${isActive ? ' nav-link-active' : ''}`
            }
          >
            Pending changes
            {pendingCount ? (
              <span className="nav-count">{pendingCount}</span>
            ) : null}
          </NavLink>
        </nav>
        <button className="btn btn-ghost logout-btn" onClick={handleLogout}>
          Log out
        </button>
      </aside>

      <main className="content">
        <div className="page-area">
          <Outlet />
        </div>
      </main>
    </div>
  )
}

export default Layout
