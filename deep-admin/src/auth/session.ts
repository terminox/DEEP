const ACCESS_KEY = 'deep_admin_access'
const REFRESH_KEY = 'deep_admin_refresh'

export function setSession(accessToken: string, refreshToken?: string) {
  localStorage.setItem(ACCESS_KEY, accessToken)
  if (refreshToken) {
    localStorage.setItem(REFRESH_KEY, refreshToken)
  }
}

export function getAccessToken(): string | null {
  return localStorage.getItem(ACCESS_KEY)
}

export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_KEY)
}

export function clearSession() {
  localStorage.removeItem(ACCESS_KEY)
  localStorage.removeItem(REFRESH_KEY)
}
