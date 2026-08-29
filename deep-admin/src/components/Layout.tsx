import { useEffect } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { clearSession } from '../auth/session'
import { usePendingCount } from '../lib/pending'

const navItems = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/categories', label: 'Categories', end: false },
  { to: '/collections', label: 'Collections', end: false },
  { to: '/plants', label: 'Plants', end: false },
  { to: '/users', label: 'Users', end: false },
  { to: '/pause-settings', label: 'Pause Settings', end: false },
  { to: '/peace-messages', label: 'Peace Messages', end: false },
]

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
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `nav-link${isActive ? ' nav-link-active' : ''}`
              }
            >
              {item.label}
            </NavLink>
          ))}

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
