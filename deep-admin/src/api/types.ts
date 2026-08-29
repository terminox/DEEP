export type Role = 'ADMIN' | 'USER'

// ---- Safe publish ----
//
// Every content row the admin edits can carry a staged change. `pending` is
// null when the row matches what the app is serving, and otherwise says how it
// differs. Publishing is what moves content; `isActive` is the separate lever
// for hiding LIVE content without deleting it.

export type DraftOp = 'CREATE' | 'UPDATE' | 'DELETE'

export type PendingMarker = {
  op: DraftOp
  changedFields: string[]
  stagedAt: string
}

export type Pending = { pending: PendingMarker | null }

export type ChangeArea = 'sound' | 'garden' | 'pause'

export const CHANGE_AREA_LABELS: Record<ChangeArea, string> = {
  sound: 'Deep Sound',
  garden: 'Mind Garden',
  pause: 'Global Pause',
}

export type FieldDiff = {
  field: string
  before: unknown
  after: unknown
}

export type CascadeImpact = {
  noun: string
  count: number
}

export type PendingChange = {
  key: string
  entity: string
  entityId: string
  noun: string
  area: ChangeArea
  op: DraftOp
  label: string
  parentKey: string | null
  parentLabel: string | null
  stagedAt: string
  authorName: string
  fields: FieldDiff[]
  cascade: CascadeImpact[]
}

export type ValidationReport = {
  resolved: string[]
  /** Pulled in automatically because a selected change depends on them. */
  addedByDependency: string[]
  blockers: string[]
  warnings: string[]
}

export type PublishResult = {
  published: number
  refs: string[]
  warnings: string[]
}

export type DiscardResult = {
  discarded: number
  refs: string[]
}


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

export type Category = Pending & {
  id: string
  slug: string
  title: string
  displayOrder: number
  isActive: boolean
  collectionCount: number
}

export type Collection = Pending & {
  id: string
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl: string | null
  isPremium: boolean
  isActive: boolean
  displayOrder: number
  trackCount: number
}

export type Track = Pending & {
  id: string
  title: string
  durationSeconds: number
  kind: TrackKind
  audioUrl: string | null
  isPremium: boolean
  isActive: boolean
  displayOrder: number
  lyricsLanguages: string[]
}

export type CollectionDetail = Pending & {
  id: string
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl: string | null
  isPremium: boolean
  isActive: boolean
  displayOrder: number
  tracks: Track[]
}

export type Lyrics = Pending & {
  id: string
  trackId: string
  languageCode: string
  content: string
}

export type StageAssetKind = 'mascot' | 'mascotBg' | 'heroVideo'

export type Plant = Pending & {
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

export type PlantStage = Pending & {
  id: string
  plantId: string
  name: string
  displayOrder: number
  sunlightRequired: number
  mascotUrl: string | null
  mascotBgUrl: string | null
  heroVideoUrl: string | null
}

export type PlantDetail = Pending & {
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

export type PauseConfig = Pending & {
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

export type PauseWelcomeMessage = Pending & {
  id: string
  text: string
  displayOrder: number
  isActive: boolean
}

export type PauseIntentionOption = Pending & {
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
  intention: string | null
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
