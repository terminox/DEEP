import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { RequireAuth } from './auth/guards'
import Layout from './components/Layout'
import LoginPage from './pages/Login'
import DashboardPage from './pages/Dashboard'
import CategoriesPage from './pages/Categories'
import CategoryDetailPage from './pages/CategoryDetail'
import CollectionsPage from './pages/Collections'
import CollectionDetailPage from './pages/CollectionDetail'
import PlantsPage from './pages/Plants'
import PlantDetailPage from './pages/PlantDetail'
import UsersPage from './pages/Users'
import PauseSettingsPage from './pages/PauseSettings'
import PeaceMessagesPage from './pages/PeaceMessages'
import PendingChangesPage from './pages/PendingChanges'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route
          element={
            <RequireAuth>
              <Layout />
            </RequireAuth>
          }
        >
          <Route path="/" element={<DashboardPage />} />
          <Route path="/changes" element={<PendingChangesPage />} />
          <Route path="/categories" element={<CategoriesPage />} />
          <Route path="/categories/:id" element={<CategoryDetailPage />} />
          <Route path="/collections" element={<CollectionsPage />} />
          <Route path="/collections/:id" element={<CollectionDetailPage />} />
          <Route path="/plants" element={<PlantsPage />} />
          <Route path="/plants/:id" element={<PlantDetailPage />} />
          <Route path="/users" element={<UsersPage />} />
          <Route path="/pause-settings" element={<PauseSettingsPage />} />
          <Route path="/peace-messages" element={<PeaceMessagesPage />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
