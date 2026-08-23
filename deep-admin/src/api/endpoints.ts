import { http } from './http'
import type {
  AdminPeaceMessage,
  AdminUser,
  Category,
  Collection,
  CollectionDetail,
  LoginResponse,
  Lyrics,
  Palette,
  PauseConfig,
  PauseIntentionOption,
  PauseStats,
  PauseWelcomeMessage,
  PeaceMessageStatus,
  Plant,
  PlantDetail,
  PlantStage,
  StageAssetKind,
  Track,
  TrackKind,
} from './types'

// ---- Auth ----
export async function login(
  email: string,
  password: string
): Promise<LoginResponse> {
  const { data } = await http.post<LoginResponse>('/admin/auth/login', {
    email,
    password,
  })
  return data
}

// ---- Users ----
export async function listUsers(): Promise<AdminUser[]> {
  const { data } = await http.get<{ users: AdminUser[] }>('/admin/users')
  return data.users
}

// ---- Categories ----
export async function listCategories(): Promise<Category[]> {
  const { data } = await http.get<{ categories: Category[] }>(
    '/admin/categories'
  )
  return data.categories
}

export type CategoryInput = {
  slug?: string
  title?: string
  displayOrder?: number
}

export async function createCategory(
  body: { slug: string; title: string; displayOrder?: number }
): Promise<Category> {
  const { data } = await http.post<{ category: Category }>(
    '/admin/categories',
    body
  )
  return data.category
}

export async function updateCategory(
  id: string,
  body: CategoryInput
): Promise<Category> {
  const { data } = await http.patch<{ category: Category }>(
    `/admin/categories/${id}`,
    body
  )
  return data.category
}

export async function deleteCategory(id: string): Promise<void> {
  await http.delete(`/admin/categories/${id}`)
}

export async function reorderCategories(ids: string[]): Promise<void> {
  await http.post('/admin/categories/reorder', { ids })
}

// ---- Collections ----
export async function listCollections(
  categoryId?: string
): Promise<Collection[]> {
  const { data } = await http.get<{ collections: Collection[] }>(
    '/admin/collections',
    { params: categoryId ? { categoryId } : undefined }
  )
  return data.collections
}

export async function getCollection(id: string): Promise<CollectionDetail> {
  const { data } = await http.get<{ collection: CollectionDetail }>(
    `/admin/collections/${id}`
  )
  return data.collection
}

export type CollectionInput = {
  categoryId?: string
  title?: string
  subtitle?: string
  palette?: Palette
  imageUrl?: string | null
  isPremium?: boolean
  displayOrder?: number
}

export async function createCollection(body: {
  categoryId: string
  title: string
  subtitle: string
  palette: Palette
  imageUrl?: string
  isPremium?: boolean
  displayOrder?: number
}): Promise<Collection> {
  const { data } = await http.post<{ collection: Collection }>(
    '/admin/collections',
    body
  )
  return data.collection
}

export async function updateCollection(
  id: string,
  body: CollectionInput
): Promise<Collection> {
  const { data } = await http.patch<{ collection: Collection }>(
    `/admin/collections/${id}`,
    body
  )
  return data.collection
}

export async function deleteCollection(id: string): Promise<void> {
  await http.delete(`/admin/collections/${id}`)
}

export async function reorderCollections(ids: string[]): Promise<void> {
  await http.post('/admin/collections/reorder', { ids })
}

// ---- Tracks ----
export async function createTrack(body: {
  collectionId: string
  title: string
  durationSeconds: number
  kind?: TrackKind
  isPremium?: boolean
  displayOrder?: number
}): Promise<Track> {
  const { data } = await http.post<{ track: Track }>('/admin/tracks', body)
  return data.track
}

export type TrackInput = {
  title?: string
  durationSeconds?: number
  kind?: TrackKind
  isPremium?: boolean
  displayOrder?: number
}

export async function updateTrack(
  id: string,
  body: TrackInput
): Promise<Track> {
  const { data } = await http.patch<{ track: Track }>(
    `/admin/tracks/${id}`,
    body
  )
  return data.track
}

export async function deleteTrack(id: string): Promise<void> {
  await http.delete(`/admin/tracks/${id}`)
}

export async function reorderTracks(ids: string[]): Promise<void> {
  await http.post('/admin/tracks/reorder', { ids })
}

export async function uploadTrackAudio(
  id: string,
  file: File
): Promise<Track> {
  const form = new FormData()
  form.append('file', file)
  const { data } = await http.post<{ track: Track }>(
    `/admin/tracks/${id}/audio`,
    form,
    { headers: { 'Content-Type': 'multipart/form-data' } }
  )
  return data.track
}

// ---- Plants ----
export async function listPlants(): Promise<Plant[]> {
  const { data } = await http.get<{ plants: Plant[] }>('/admin/plants')
  return data.plants
}

export async function getPlant(id: string): Promise<PlantDetail> {
  const { data } = await http.get<{ plant: PlantDetail }>(`/admin/plants/${id}`)
  return data.plant
}

export type PlantInput = {
  name?: string
  tagline?: string
  palette?: Palette
  imageUrl?: string | null
  isPremium?: boolean
  isDefault?: boolean
  isActive?: boolean
  displayOrder?: number
}

export async function createPlant(body: {
  id: string
  name: string
  tagline: string
  palette: Palette
  isPremium?: boolean
  isDefault?: boolean
  isActive?: boolean
  displayOrder?: number
}): Promise<PlantDetail> {
  const { data } = await http.post<{ plant: PlantDetail }>('/admin/plants', body)
  return data.plant
}

export async function updatePlant(
  id: string,
  body: PlantInput
): Promise<PlantDetail> {
  const { data } = await http.patch<{ plant: PlantDetail }>(
    `/admin/plants/${id}`,
    body
  )
  return data.plant
}

export async function deletePlant(id: string): Promise<void> {
  await http.delete(`/admin/plants/${id}`)
}

export async function reorderPlants(ids: string[]): Promise<void> {
  await http.post('/admin/plants/reorder', { ids })
}

export async function uploadPlantImage(id: string, file: File): Promise<Plant> {
  const form = new FormData()
  form.append('file', file)
  const { data } = await http.post<{ plant: Plant }>(
    `/admin/plants/${id}/image`,
    form,
    { headers: { 'Content-Type': 'multipart/form-data' } }
  )
  return data.plant
}

// ---- Plant stages ----
export async function createStage(
  plantId: string,
  body: { name: string; sunlightRequired: number; displayOrder?: number }
): Promise<PlantStage> {
  const { data } = await http.post<{ stage: PlantStage }>(
    `/admin/plants/${plantId}/stages`,
    body
  )
  return data.stage
}

export type StageInput = {
  name?: string
  sunlightRequired?: number
}

export async function updateStage(
  id: string,
  body: StageInput
): Promise<PlantStage> {
  const { data } = await http.patch<{ stage: PlantStage }>(
    `/admin/plant-stages/${id}`,
    body
  )
  return data.stage
}

export async function deleteStage(id: string): Promise<void> {
  await http.delete(`/admin/plant-stages/${id}`)
}

export async function reorderStages(
  plantId: string,
  ids: string[]
): Promise<void> {
  await http.post(`/admin/plants/${plantId}/stages/reorder`, { ids })
}

export async function uploadStageAsset(
  stageId: string,
  kind: StageAssetKind,
  file: File
): Promise<PlantStage> {
  const form = new FormData()
  form.append('file', file)
  const { data } = await http.post<{ stage: PlantStage }>(
    `/admin/plant-stages/${stageId}/assets/${kind}`,
    form,
    { headers: { 'Content-Type': 'multipart/form-data' } }
  )
  return data.stage
}

export async function deleteStageAsset(
  stageId: string,
  kind: StageAssetKind
): Promise<PlantStage> {
  const { data } = await http.delete<{ stage: PlantStage }>(
    `/admin/plant-stages/${stageId}/assets/${kind}`
  )
  return data.stage
}

// ---- Lyrics ----
export async function listLyrics(trackId: string): Promise<Lyrics[]> {
  const { data } = await http.get<{ lyrics: Lyrics[] }>(
    `/admin/tracks/${trackId}/lyrics`
  )
  return data.lyrics
}

export async function upsertLyrics(
  trackId: string,
  languageCode: string,
  content: string
): Promise<Lyrics> {
  const { data } = await http.put<{ lyrics: Lyrics }>(
    `/admin/tracks/${trackId}/lyrics`,
    { languageCode, content }
  )
  return data.lyrics
}

export async function deleteLyrics(
  trackId: string,
  lang: string
): Promise<void> {
  await http.delete(`/admin/tracks/${trackId}/lyrics/${lang}`)
}

// ---- Global Pause ----
export async function getPauseConfig(): Promise<PauseConfig> {
  const { data } = await http.get<{ config: PauseConfig }>(
    '/admin/pause/config'
  )
  return data.config
}

export type PauseConfigInput = {
  timezone: string
  lobbyStart: string
  welcomeStart: string
  meditationStart: string
  feedbackStart: string
  windowEnd: string
  lobbyAudioPath: string
  meditationAudioPath: string
  meditationDurationSeconds: number
}

export async function updatePauseConfig(
  body: PauseConfigInput
): Promise<PauseConfig> {
  const { data } = await http.put<{ config: PauseConfig }>(
    '/admin/pause/config',
    body
  )
  return data.config
}

// ---- Pause welcome messages ----
export async function listPauseWelcomeMessages(): Promise<
  PauseWelcomeMessage[]
> {
  const { data } = await http.get<{ messages: PauseWelcomeMessage[] }>(
    '/admin/pause/welcome-messages'
  )
  return data.messages
}

export async function createPauseWelcomeMessage(body: {
  text: string
  displayOrder?: number
  isActive?: boolean
}): Promise<PauseWelcomeMessage> {
  const { data } = await http.post<{ message: PauseWelcomeMessage }>(
    '/admin/pause/welcome-messages',
    body
  )
  return data.message
}

export type PauseWelcomeMessageInput = {
  text?: string
  displayOrder?: number
  isActive?: boolean
}

export async function updatePauseWelcomeMessage(
  id: string,
  body: PauseWelcomeMessageInput
): Promise<PauseWelcomeMessage> {
  const { data } = await http.patch<{ message: PauseWelcomeMessage }>(
    `/admin/pause/welcome-messages/${id}`,
    body
  )
  return data.message
}

export async function deletePauseWelcomeMessage(id: string): Promise<void> {
  await http.delete(`/admin/pause/welcome-messages/${id}`)
}

export async function reorderPauseWelcomeMessages(
  ids: string[]
): Promise<void> {
  await http.post('/admin/pause/welcome-messages/reorder', { ids })
}

// ---- Pause intentions ----
export async function listPauseIntentions(): Promise<PauseIntentionOption[]> {
  const { data } = await http.get<{ intentions: PauseIntentionOption[] }>(
    '/admin/pause/intentions'
  )
  return data.intentions
}

export async function createPauseIntention(body: {
  key: string
  label: string
  displayOrder?: number
  isActive?: boolean
}): Promise<PauseIntentionOption> {
  const { data } = await http.post<{ intention: PauseIntentionOption }>(
    '/admin/pause/intentions',
    body
  )
  return data.intention
}

export type PauseIntentionInput = {
  key?: string
  label?: string
  displayOrder?: number
  isActive?: boolean
}

export async function updatePauseIntention(
  id: string,
  body: PauseIntentionInput
): Promise<PauseIntentionOption> {
  const { data } = await http.patch<{ intention: PauseIntentionOption }>(
    `/admin/pause/intentions/${id}`,
    body
  )
  return data.intention
}

export async function deletePauseIntention(id: string): Promise<void> {
  await http.delete(`/admin/pause/intentions/${id}`)
}

export async function reorderPauseIntentions(ids: string[]): Promise<void> {
  await http.post('/admin/pause/intentions/reorder', { ids })
}

// ---- Peace messages ----
export async function listPeaceMessages(params?: {
  status?: PeaceMessageStatus
  pauseDate?: string
}): Promise<AdminPeaceMessage[]> {
  const { data } = await http.get<{ messages: AdminPeaceMessage[] }>(
    '/admin/pause/messages',
    { params }
  )
  return data.messages
}

export async function updatePeaceMessageStatus(
  id: string,
  status: PeaceMessageStatus
): Promise<AdminPeaceMessage> {
  const { data } = await http.patch<{ message: AdminPeaceMessage }>(
    `/admin/pause/messages/${id}`,
    { status }
  )
  return data.message
}

// ---- Pause stats ----
export async function getPauseStats(days = 7): Promise<PauseStats> {
  const { data } = await http.get<PauseStats>('/admin/pause/stats', {
    params: { days },
  })
  return data
}
