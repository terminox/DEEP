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

export type StageAssetKind = 'mascot' | 'mascotBg' | 'heroVideo'

export type Plant = {
  id: string
  name: string
  tagline: string
  imageUrl: string | null
  palette: Palette
  displayOrder: number
  isPremium: boolean
  isDefault: boolean
  isActive: boolean
  stageCount?: number
}

export type PlantStage = {
  id: string
  plantId: string
  name: string
  displayOrder: number
  sunlightRequired: number
  mascotUrl: string | null
  mascotBgUrl: string | null
  heroVideoUrl: string | null
}

export type PlantDetail = {
  id: string
  name: string
  tagline: string
  imageUrl: string | null
  palette: Palette
  displayOrder: number
  isPremium: boolean
  isDefault: boolean
  isActive: boolean
  stages: PlantStage[]
}

export type PauseConfig = {
  id: number
  timezone: string
  lobbyStart: string
  welcomeStart: string
  meditationStart: string
  windowEnd: string
  lobbyAudioPath: string
  meditationAudioPath: string
  // Measured off meditationAudioPath by the server. The meditation phase runs
  // meditationStart -> meditationStart + this, so there is no separate end time.
  meditationDurationSeconds: number
  updatedAt: string
}

export type PauseWelcomeMessage = {
  id: string
  text: string
  displayOrder: number
  isActive: boolean
}

export type PauseIntentionOption = {
  id: string
  key: string
  label: string
  displayOrder: number
  isActive: boolean
}

export type PeaceMessageStatus = 'PUBLISHED' | 'HIDDEN'

export const PEACE_MESSAGE_STATUSES: PeaceMessageStatus[] = [
  'PUBLISHED',
  'HIDDEN',
]

export type AdminPeaceMessage = {
  id: string
  userId: string | null
  displayName: string
  countryISO: string | null
  text: string
  status: PeaceMessageStatus
  pauseDate: string
  createdAt: string
}

export type PauseDayStats = {
  intentions: Record<string, number>
  moods: Record<string, number>
  total: number
}

export type PauseStats = {
  days: number
  byDate: Record<string, PauseDayStats>
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

export type UploadedMedia = {
  path: string // relative /media/... path to store on the row
  url: string // absolute URL, for immediate preview
  durationSeconds: number | null // audio only; measured server-side, null if unreadable
}
