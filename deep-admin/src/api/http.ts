import axios, {
  AxiosError,
  type AxiosRequestConfig,
  type InternalAxiosRequestConfig,
} from 'axios'
import {
  clearSession,
  getAccessToken,
  getRefreshToken,
  setSession,
} from '../auth/session'

const baseURL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'

export const http = axios.create({ baseURL })

// A bare axios instance used only for the refresh call so it does not run
// through the interceptors below (which would recurse on failure).
const refreshClient = axios.create({ baseURL })

http.interceptors.request.use((config) => {
  const token = getAccessToken()
  if (token) {
    config.headers = config.headers ?? {}
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

type RetriableConfig = InternalAxiosRequestConfig & { _retried?: boolean }

// Single-flight refresh so concurrent 401s share one refresh round-trip.
let refreshInFlight: Promise<string | null> | null = null

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = getRefreshToken()
  if (!refreshToken) return null

  try {
    const { data } = await refreshClient.post('/auth/refresh', { refreshToken })
    // Refresh tokens rotate — always persist the new one from the response.
    setSession(data.accessToken, data.refreshToken)
    return data.accessToken as string
  } catch {
    return null
  }
}

function redirectToLogin() {
  clearSession()
  if (window.location.pathname !== '/login') {
    window.location.href = '/login'
  }
}

http.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as RetriableConfig | undefined
    const status = error.response?.status

    if (status !== 401 || !original || original._retried) {
      if (status === 401) redirectToLogin()
      return Promise.reject(error)
    }

    original._retried = true

    if (!refreshInFlight) {
      refreshInFlight = refreshAccessToken().finally(() => {
        refreshInFlight = null
      })
    }

    const newToken = await refreshInFlight

    if (!newToken) {
      redirectToLogin()
      return Promise.reject(error)
    }

    original.headers = original.headers ?? {}
    original.headers.Authorization = `Bearer ${newToken}`
    return http(original as AxiosRequestConfig)
  }
)
