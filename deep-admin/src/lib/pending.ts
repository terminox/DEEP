import { useQuery } from '@tanstack/react-query'
import { getPendingCount, listPendingChanges } from '../api/endpoints'
import type { DraftOp, PendingChange, PendingMarker } from '../api/types'

/** Shared prefix so one invalidate refreshes both the count and the list. */
export const PENDING_KEY = ['pending'] as const
export const PENDING_COUNT_KEY = ['pending', 'count'] as const
export const PENDING_LIST_KEY = ['pending', 'list'] as const

export function usePendingCount() {
  return useQuery({
    queryKey: PENDING_COUNT_KEY,
    queryFn: getPendingCount,
  })
}

export function usePendingChanges() {
  return useQuery({
    queryKey: PENDING_LIST_KEY,
    queryFn: listPendingChanges,
  })
}

/** What the badge on a row says. Kept here so every page words it identically. */
export function pendingLabel(op: DraftOp): string {
  if (op === 'CREATE') return 'Draft'
  if (op === 'DELETE') return 'Will delete'
  return 'Edited'
}

export function pendingRef(entity: string, id: string): string {
  return `${entity}:${id}`
}

/** The refs for one record plus everything staged underneath it. */
export function refsUnder(changes: PendingChange[], key: string): string[] {
  const out = new Set<string>([key])
  let grew = true
  while (grew) {
    grew = false
    for (const change of changes) {
      if (out.has(change.key) || !change.parentKey) continue
      if (out.has(change.parentKey)) {
        out.add(change.key)
        grew = true
      }
    }
  }
  return [...out].filter((ref) => changes.some((c) => c.key === ref))
}

/** Human wording for a field name, so diffs don't read like column names. */
const FIELD_LABELS: Record<string, string> = {
  displayOrder: 'Order',
  isActive: 'Visible',
  isPremium: 'Premium',
  isDefault: 'Onboarding default',
  categoryId: 'Category',
  collectionId: 'Collection',
  plantId: 'Plant',
  trackId: 'Track',
  imageUrl: 'Image',
  audioPath: 'Audio',
  mascotPath: 'Mascot',
  mascotBgPath: 'Mascot background',
  heroVideoPath: 'Hero video',
  languageCode: 'Language',
  sunlightRequired: 'Sunlight required',
  durationSeconds: 'Duration',
  meditationDurationSeconds: 'Meditation length',
  lobbyDurationSeconds: "Lounge set length",
  lobbyAudioPath: 'Lobby audio',
  meditationAudioPath: 'Meditation audio',
  lobbyStart: 'Lobby start',
  welcomeStart: 'Welcome start',
  meditationStart: 'Meditation start',
  windowEnd: 'Window end',
}

export function fieldLabel(field: string): string {
  if (FIELD_LABELS[field]) return FIELD_LABELS[field]
  // "subtitle" → "Subtitle", "someField" → "Some field"
  const spaced = field.replace(/([A-Z])/g, ' $1').toLowerCase()
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

/** Renders a diff value compactly; long text is trimmed, empties are named. */
export function formatValue(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  const text = String(value)
  return text.length > 80 ? `${text.slice(0, 79)}…` : text
}

export type { PendingChange, PendingMarker }
