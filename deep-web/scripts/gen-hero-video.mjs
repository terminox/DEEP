// One-off: generate the landscape hero video (a companion to the iOS welcome.mp4) through
// OpenRouter's video API, then make it loop seamlessly and encode it for the web.
//
//   node scripts/gen-hero-video.mjs --models   list video models and what they support
//   node scripts/gen-hero-video.mjs            generate, download, loop, encode
//
// Reads OPENROUTER_API_KEY from deep-web/.env.local (gitignored). Never paste the key into chat.
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const out = join(root, 'public/media')
const work = join(root, 'scripts/.hero-work')
const API = 'https://openrouter.ai/api/v1'

function readKey() {
  const file = join(root, '.env.local')
  if (!existsSync(file)) throw new Error('Create deep-web/.env.local with OPENROUTER_API_KEY=… first.')
  const line = readFileSync(file, 'utf8').split('\n').find((l) => l.startsWith('OPENROUTER_API_KEY='))
  const key = line?.slice('OPENROUTER_API_KEY='.length).trim().replace(/^["']|["']$/g, '')
  if (!key) throw new Error('OPENROUTER_API_KEY is missing from deep-web/.env.local.')
  return key
}

const key = readKey()
const headers = { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }

async function api(path, init = {}) {
  const res = await fetch(`${API}${path}`, { ...init, headers: { ...headers, ...init.headers } })
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path} → ${res.status}: ${await res.text()}`)
  return res
}

if (process.argv.includes('--models')) {
  const { data } = await (await api('/videos/models')).json()
  for (const m of data ?? []) {
    console.log(m.id, JSON.stringify({
      durations: m.supported_durations,
      resolutions: m.supported_resolutions,
      aspect: m.supported_aspect_ratios,
      pricing: m.pricing,
    }))
  }
  process.exit(0)
}

const model = process.env.HERO_MODEL ?? 'google/veo-3.1'
const prompt = [
  'A serene sunrise over a perfectly still alpine lake, wide cinematic landscape.',
  'Snow-dusted mountains frame a soft glowing sun low on the horizon; its reflection shimmers on the water.',
  'Gentle mist drifts slowly across the lake surface; a few slow ripples spread outward.',
  'Dreamy pastel palette: lavender sky, blush and peach light, pale cream highlights, soft lilac shadows.',
  'Locked-off tripod camera with an almost imperceptible slow push-in. Calm, weightless, meditative.',
  'No people, no birds, no text, no boats, no camera shake, no cuts.',
].join(' ')

mkdirSync(work, { recursive: true })

// Style reference: a frame of the iOS welcome video, so the web hero reads as the same film.
const refJpg = join(work, 'reference.jpg')
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-ss', '2', '-i', join(out, 'welcome.mp4'), '-frames:v', '1', '-q:v', '3', refJpg])
const reference = `data:image/jpeg;base64,${readFileSync(refJpg).toString('base64')}`

const body = {
  model,
  prompt,
  duration: 8,
  resolution: '1080p',
  aspect_ratio: '16:9',
  generate_audio: false,
  input_references: [{ type: 'image_url', image_url: { url: reference } }],
}

let job
try {
  job = await (await api('/videos', { method: 'POST', body: JSON.stringify(body) })).json()
} catch (error) {
  // If the provider rejects inline references, fall back to text-only rather than failing the run.
  console.warn(`With reference failed, retrying text-only.\n${error.message}`)
  delete body.input_references
  job = await (await api('/videos', { method: 'POST', body: JSON.stringify(body) })).json()
}
console.log(`Job ${job.id} submitted on ${model}.`)
writeFileSync(join(work, 'job.json'), JSON.stringify(job, null, 2))

let status = job
const started = Date.now()
while (!['completed', 'failed', 'cancelled', 'expired'].includes(status.status)) {
  await new Promise((r) => setTimeout(r, 10_000))
  status = await (await api(`/videos/${job.id}`)).json()
  console.log(`${Math.round((Date.now() - started) / 1000)}s ${status.status}`)
}
writeFileSync(join(work, 'status.json'), JSON.stringify(status, null, 2))
if (status.status !== 'completed') throw new Error(`Generation ended as ${status.status}: ${JSON.stringify(status)}`)
if (status.usage?.cost != null) console.log(`Cost: $${status.usage.cost}`)

const raw = join(work, 'raw.mp4')
const content = await api(`/videos/${job.id}/content?index=0`)
writeFileSync(raw, Buffer.from(await content.arrayBuffer()))

// Seamless loop: drop the first second, then crossfade the tail into it.
const duration = parseFloat(
  execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', raw]).toString(),
)
const fade = 1
const filter = [
  `[0:v]split[a][b]`,
  `[a]trim=${fade}:${duration},setpts=PTS-STARTPTS[main]`,
  `[b]trim=0:${fade},setpts=PTS-STARTPTS[head]`,
  `[main][head]xfade=transition=fade:duration=${fade}:offset=${(duration - 2 * fade).toFixed(3)},scale=1920:-2,format=yuv420p[v]`,
].join(';')
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', raw, '-filter_complex', filter, '-map', '[v]', '-an',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '26', '-movflags', '+faststart', join(out, 'hero-lake.mp4')])
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', join(out, 'hero-lake.mp4'), '-frames:v', '1', '-q:v', '4', join(out, 'hero-lake-poster.jpg')])
console.log('Wrote public/media/hero-lake.mp4 and hero-lake-poster.jpg')
