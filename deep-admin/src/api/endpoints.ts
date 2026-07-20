import { http } from './http'
import type {
  AdminUser,
  Category,
  Collection,
  CollectionDetail,
  LoginResponse,
  Lyrics,
  Palette,
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
