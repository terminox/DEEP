import { useQuery } from '@tanstack/react-query'
import { listUsers } from '../api/endpoints'
import { apiErrorMessage } from '../api/errors'

function UsersPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: () => listUsers(),
  })

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Users</h1>
          <div className="page-subtitle">Read-only list of app accounts</div>
        </div>
      </div>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

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
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((u) => (
                <tr key={u.id}>
                  <td className="title-cell">{u.displayName}</td>
                  <td>{u.email}</td>
                  <td>
                    <span className="badge badge-role">{u.role}</span>
                  </td>
                  <td className="muted">
                    {new Date(u.createdAt).toLocaleDateString()}
                  </td>
                </tr>
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={4} className="empty">
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
