import { useEffect } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { clearSession } from '../auth/session'
import { usePendingCount } from '../lib/pending'
import { CHANGE_AREA_LABELS } from '../api/types'

type NavItem = { to: string; label: string; end?: boolean; spaced?: boolean }

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
      { to: '/peace-messages', label: 'Peace messages' },
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
          Deep Admin
        </div>
        <nav className="nav-links">
          {navEntries.map((entry) =>
            entry.kind === 'group' ? (
              <div className="nav-group" key={entry.title}>
                <div className="nav-group-title">{entry.title}</div>
                {entry.items.map((item) => (
                  <NavLink key={item.to} to={item.to} className={linkClass(item)}>
                    {item.label}
                  </NavLink>
                ))}
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
