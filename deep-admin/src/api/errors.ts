import { AxiosError } from 'axios'
import type { ApiError } from './types'

export function apiErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  if (err instanceof AxiosError) {
    const data = err.response?.data as ApiError | undefined
    if (data?.error?.message) return data.error.message
    if (err.message) return err.message
  }
  if (err instanceof Error) return err.message
  return fallback
}
