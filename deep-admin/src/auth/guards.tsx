import type { ReactElement } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { getAccessToken } from './session'

type Props = {
  children: ReactElement
}

export function RequireAuth({ children }: Props) {
  const token = getAccessToken()
  const location = useLocation()

  if (!token) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }

  return children
}
