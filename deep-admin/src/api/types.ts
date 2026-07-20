export type Role = 'ADMIN' | 'USER'

export type Palette =
  | 'tide'
  | 'dusk'
  | 'bloom'
  | 'ember'
  | 'mist'
  | 'aurora'
  | 'dawn'

export const PALETTES: Palette[] = [
  'tide',
  'dusk',
  'bloom',
  'ember',
  'mist',
  'aurora',
  'dawn',
]

export type TrackKind = 'INSTRUMENTAL' | 'GUIDED'

export const TRACK_KINDS: TrackKind[] = ['INSTRUMENTAL', 'GUIDED']

export type AdminUser = {
  id: string
  email: string
  displayName: string
  role: Role
  createdAt: string
}

export type Category = {
  id: string
  slug: string
  title: string
  displayOrder: number
  collectionCount: number
}

export type Collection = {
  id: string
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl: string | null
  isPremium: boolean
  displayOrder: number
  trackCount: number
}

export type Track = {
  id: string
  title: string
  durationSeconds: number
  kind: TrackKind
  audioUrl: string | null
  isPremium: boolean
  displayOrder: number
  lyricsLanguages: string[]
}

export type CollectionDetail = {
  id: string
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl: string | null
  isPremium: boolean
  displayOrder: number
  tracks: Track[]
}

export type Lyrics = {
  id: string
  trackId: string
  languageCode: string
  content: string
}

export type LoginResponse = {
  user: AdminUser
  accessToken: string
  refreshToken: string
  expiresIn: number
}

export type ApiError = {
  error: {
    code: string
    message: string
    issues?: unknown
  }
}
