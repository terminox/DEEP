import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { clearSession } from '../auth/session'

const navItems = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/categories', label: 'Categories', end: false },
  { to: '/collections', label: 'Collections', end: false },
  { to: '/users', label: 'Users', end: false },
]

function Layout() {
  const navigate = useNavigate()

  const handleLogout = () => {
    clearSession()
    navigate('/login', { replace: true })
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-dot" />
          Deep Admin
        </div>
        <nav>
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
