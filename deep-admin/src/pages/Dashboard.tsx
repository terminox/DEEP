import { useQuery } from '@tanstack/react-query'
import { listCategories, listCollections, listUsers } from '../api/endpoints'

function StatCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="stat-card">
      <div className="stat-value">{value}</div>
      <div className="stat-label">{label}</div>
    </div>
  )
}

function DashboardPage() {
  const categories = useQuery({
    queryKey: ['categories'],
    queryFn: () => listCategories(),
  })
  const collections = useQuery({
    queryKey: ['collections', undefined],
    queryFn: () => listCollections(),
  })
  const users = useQuery({ queryKey: ['users'], queryFn: () => listUsers() })

  const loading =
    categories.isLoading || collections.isLoading || users.isLoading

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <div className="page-subtitle">Content overview for the Deep app</div>
        </div>
      </div>

      {loading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="stat-grid">
          <StatCard label="Categories" value={categories.data?.length ?? 0} />
          <StatCard label="Collections" value={collections.data?.length ?? 0} />
          <StatCard label="Users" value={users.data?.length ?? 0} />
        </div>
      )}
    </div>
  )
}

export default DashboardPage
