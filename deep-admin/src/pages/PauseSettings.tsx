import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createPauseIntention,
  createPauseSlot,
  createPauseWelcomeMessage,
  deletePauseIntention,
  deletePauseSlot,
  deletePauseWelcomeMessage,
  getPauseConfig,
  listPauseIntentions,
  listPauseSlots,
  listPauseWelcomeMessages,
  reorderPauseIntentions,
  reorderPauseWelcomeMessages,
  updatePauseConfig,
  updatePauseIntention,
  updatePauseSlot,
  updatePauseWelcomeMessage,
  uploadMedia,
} from '../api/endpoints'
import type {
  PauseIntentionOption,
  PauseSlot,
  PauseWelcomeMessage,
} from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { MediaDropzone } from '../components/MediaDropzone'
import { PendingBar } from '../components/PendingBar'
import { PendingBadge } from '../components/PendingBadge'

type ConfigForm = {
  timezone: string
  lobbyAudioPath: string
  lobbyDurationSeconds: string
  meditationAudioPath: string
  meditationDurationSeconds: string
}

/** The four wall-clock boundaries of one daily session. */
type SlotForm = {
  lobbyStart: string
  welcomeStart: string
  meditationStart: string
  windowEnd: string
}

const TIME_RE = /^\d{2}:\d{2}:\d{2}$/

const EMPTY_SLOT: SlotForm = {
  lobbyStart: '',
  welcomeStart: '',
  meditationStart: '',
  windowEnd: '',
}

// A /media/... path is a file the server can measure; anything else is an
// external URL whose length only the admin can supply.
const isUploadedFile = (path: string) => path.startsWith('/media/')

/** Parses an HH:mm:ss value into seconds since local midnight, per TIME_RE. */
function timeToSeconds(time: string): number | null {
  if (!TIME_RE.test(time)) return null
  const [h, m, s] = time.split(':').map(Number)
  return h * 3600 + m * 60 + s
}

/**
 * Formats seconds since local midnight back into the HH:mm:ss shape the
 * other time fields use.
 */
function secondsToTime(totalSeconds: number): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  const h = Math.floor(totalSeconds / 3600)
  const m = Math.floor((totalSeconds % 3600) / 60)
  const s = totalSeconds % 60
  return `${pad(h)}:${pad(m)}:${pad(s)}`
}

// "10:00", "2:12" - the track's length as a listener would say it.
function formatLength(seconds: number): string {
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

/** How a session is named in a message, matching the server's wording. */
function slotName(slot: SlotForm): string {
  return `the ${slot.meditationStart.slice(0, 5)} session`
}

/**
 * Mirrors the server rules in lib/drafts/validators.ts, so a mistake is named
 * while it is being typed rather than on save. Every rule here is a rule about
 * the whole day: the meditation's length lives on the config while the windows
 * live on the sessions, so none of them can be judged one row at a time.
 */
function scheduleProblems(
  slots: SlotForm[],
  meditationDurationSeconds: number
): string[] {
  const problems: string[] = []
  if (slots.length === 0) {
    return ['The Global Pause needs at least one session time.']
  }

  for (const slot of slots) {
    const labelled: [string, string][] = [
      ['Lobby start', slot.lobbyStart],
      ['Welcome start', slot.welcomeStart],
      ['Meditation start', slot.meditationStart],
      ['Window end', slot.windowEnd],
    ]
    const malformed = labelled.find(([, value]) => !TIME_RE.test(value))
    if (malformed) {
      problems.push(`${malformed[0]} must be HH:mm:ss`)
      continue
    }
    if (slot.windowEnd <= slot.lobbyStart) {
      problems.push(
        `${slotName(slot)} ends at ${slot.windowEnd}, at or before it opens at ${slot.lobbyStart} — a session cannot run past midnight.`
      )
      continue
    }
    const order = labelled.map(([, value]) => value)
    if (!order.every((t, i) => i === 0 || order[i - 1] < t)) {
      problems.push(`In ${slotName(slot)}: phase times must be strictly increasing.`)
      continue
    }
    const end = timeToSeconds(slot.meditationStart)! + meditationDurationSeconds
    if (end >= timeToSeconds(slot.windowEnd)!) {
      problems.push(
        `In ${slotName(slot)}, a ${meditationDurationSeconds}s meditation starting ${slot.meditationStart} runs to ${secondsToTime(end)}, past its window end ${slot.windowEnd} — extend that session's window end.`
      )
    }
  }

  const ordered = [...slots].sort((a, b) => a.lobbyStart.localeCompare(b.lobbyStart))
  for (let i = 1; i < ordered.length; i += 1) {
    const prev = ordered[i - 1]
    const next = ordered[i]
    if (next.lobbyStart < prev.windowEnd) {
      problems.push(
        `${slotName(next)} opens at ${next.lobbyStart}, before ${slotName(prev)} closes at ${prev.windowEnd} — sessions cannot overlap.`
      )
    }
  }

  return problems
}

/**
 * The meditation phase runs meditationStart -> meditationStart + the track's
 * length, and the feedback phase takes the rest of the window. Both are derived
 * here exactly as the server derives them, so the admin can see what a new
 * track did to a session rather than having to keep an end time in sync with it.
 */
function describeWindow(
  slot: SlotForm,
  meditationDurationSeconds: number
): { meditation: string; feedback: string } | null {
  const start = timeToSeconds(slot.meditationStart)
  if (start == null || meditationDurationSeconds <= 0) return null
  const end = secondsToTime(start + meditationDurationSeconds)
  return {
    meditation: `${slot.meditationStart} – ${end} (${formatLength(meditationDurationSeconds)})`,
    feedback: `${end} – ${slot.windowEnd}`,
  }
}

/**
 * Where DJ Fuku's set lands inside this session's lobby phase. The app plays a
 * short bundled intro clip first, so the music starts a beat after lobbyStart
 * and this end time is a few seconds early — close enough to answer the only
 * question worth asking here, which is whether the track fits before the
 * welcome. `overruns` says it doesn't: the app cuts the set off at the welcome
 * rather than letting it play over the countdown.
 *
 * The track is shared by every session, so a set that fits one session's lobby
 * can overrun another's.
 */
function describeSet(
  slot: SlotForm,
  lobbyDurationSeconds: number
): { window: string; overruns: boolean } | null {
  const start = timeToSeconds(slot.lobbyStart)
  const welcome = timeToSeconds(slot.welcomeStart)
  if (start == null || welcome == null) return null
  if (lobbyDurationSeconds <= 0) return null
  const end = start + lobbyDurationSeconds
  return {
    window: `${slot.lobbyStart} – ${secondsToTime(end)} (${formatLength(lobbyDurationSeconds)})`,
    overruns: end >= welcome,
  }
}

function ConfigPanel() {
  const qc = useQueryClient()
  const { data, isLoading, error } = useQuery({
    queryKey: ['pause-config'],
    queryFn: () => getPauseConfig(),
  })

  // `edits` holds only what the admin has touched; the fetched config fills
  // in the rest, so no effect is needed to seed the form.
  const [edits, setEdits] = useState<Partial<ConfigForm>>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)

  const form: ConfigForm | null = data
    ? {
        timezone: data.timezone,
        lobbyAudioPath: data.lobbyAudioPath,
        lobbyDurationSeconds: String(data.lobbyDurationSeconds),
        meditationAudioPath: data.meditationAudioPath,
        meditationDurationSeconds: String(data.meditationDurationSeconds),
        ...edits,
      }
    : null

  const save = useMutation({
    mutationFn: (body: ConfigForm) =>
      updatePauseConfig({
        timezone: body.timezone,
        lobbyAudioPath: body.lobbyAudioPath,
        lobbyDurationSeconds: Number(body.lobbyDurationSeconds),
        meditationAudioPath: body.meditationAudioPath,
        meditationDurationSeconds: Number(body.meditationDurationSeconds),
      }),
    onSuccess: () => {
      setEdits({})
      setFormError(null)
      setSaved(true)
      // A new track length changes every session's derived windows.
      qc.invalidateQueries({ queryKey: ['pause-config'] })
      qc.invalidateQueries({ queryKey: ['pause-slots'] })
    },
    onError: (e) => {
      setSaved(false)
      setFormError(apiErrorMessage(e))
    },
  })

  const update = (patch: Partial<ConfigForm>) => {
    setSaved(false)
    setEdits((prev) => ({ ...prev, ...patch }))
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    if (!form) return
    const lobbyDuration = Number(form.lobbyDurationSeconds)
    if (!Number.isInteger(lobbyDuration) || lobbyDuration <= 0) {
      setSaved(false)
      setFormError('Lounge set duration must be a positive whole number of seconds')
      return
    }
    const duration = Number(form.meditationDurationSeconds)
    if (!Number.isInteger(duration) || duration <= 0) {
      setSaved(false)
      setFormError('Meditation duration must be a positive whole number of seconds')
      return
    }
    setFormError(null)
    save.mutate(form)
  }

  return (
    <div className="panel">
      <div className="panel-title">Timezone &amp; audio</div>
      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}
      {formError && <div className="error-banner">{formError}</div>}
      {saved && (
        <div className="success-banner">
          Saved as a pending change. Today&apos;s Global Pause is unchanged until
          you publish it.
        </div>
      )}
      <PendingBar entityKey="PAUSE_CONFIG:1" />
      {isLoading || !form ? (
        <div className="state">Loading…</div>
      ) : (
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="field">
              <label>Timezone</label>
              <input
                value={form.timezone}
                onChange={(e) => update({ timezone: e.target.value })}
                placeholder="Asia/Bangkok"
                required
              />
              <div className="field-hint">
                Every session time below is written in this zone.
              </div>
            </div>
            <div className="field">
              <label>Lounge set duration (seconds)</label>
              <input
                type="number"
                min={1}
                value={form.lobbyDurationSeconds}
                onChange={(e) => update({ lobbyDurationSeconds: e.target.value })}
                readOnly={isUploadedFile(form.lobbyAudioPath)}
                required
              />
              <div className="field-hint">
                {isUploadedFile(form.lobbyAudioPath)
                  ? 'Read from the lobby audio file. Upload a new track to change it.'
                  : "This audio is an external URL, so its length can't be measured — set it here."}
              </div>
            </div>
            <div className="field">
              <label>Meditation duration (seconds)</label>
              <input
                type="number"
                min={1}
                value={form.meditationDurationSeconds}
                onChange={(e) =>
                  update({ meditationDurationSeconds: e.target.value })
                }
                readOnly={isUploadedFile(form.meditationAudioPath)}
                required
              />
              <div className="field-hint">
                {isUploadedFile(form.meditationAudioPath)
                  ? 'Read from the meditation audio file. Upload a new track to change it.'
                  : "This audio is an external URL, so its length can't be measured — set it here."}
              </div>
            </div>
          </div>
          <MediaDropzone
            label="Lobby audio"
            kind="audio"
            currentUrl={form.lobbyAudioPath || null}
            onUpload={async (file, onProgress) => {
              const media = await uploadMedia('audio', file, onProgress)
              // Measured server-side as it was stored, exactly like the
              // meditation track below: how long Fuku stays on air is the
              // length of the file, not a number anyone types.
              update({
                lobbyAudioPath: media.path,
                ...(media.durationSeconds != null
                  ? { lobbyDurationSeconds: String(media.durationSeconds) }
                  : {}),
              })
            }}
            urlInput={{
              value: form.lobbyAudioPath,
              onChange: (v) => update({ lobbyAudioPath: v }),
              placeholder: '/media/audio/global-pause-lobby.mp3',
            }}
          />
          <MediaDropzone
            label="Meditation audio"
            kind="audio"
            currentUrl={form.meditationAudioPath || null}
            onUpload={async (file, onProgress) => {
              const media = await uploadMedia('audio', file, onProgress)
              // The server measured it as it stored it, so the derived windows
              // in the sessions below update the moment the file lands — no
              // typing, and no browser guess that quietly returns nothing for
              // some containers.
              update({
                meditationAudioPath: media.path,
                ...(media.durationSeconds != null
                  ? { meditationDurationSeconds: String(media.durationSeconds) }
                  : {}),
              })
            }}
            urlInput={{
              value: form.meditationAudioPath,
              onChange: (v) => update({ meditationAudioPath: v }),
              placeholder: '/media/audio/inner-light.mp3',
            }}
          />
          <div className="field-hint">
            Both tracks are shared by every session of the day. A longer
            meditation has to fit inside every session&apos;s window, so one that
            overruns any of them is refused here.
          </div>
          <div className="form-actions">
            <button className="btn" type="submit" disabled={save.isPending}>
              Save configuration
            </button>
          </div>
        </form>
      )}
    </div>
  )
}

function SlotRow({
  slot,
  slots,
  meditationDurationSeconds,
  lobbyDurationSeconds,
  canDelete,
}: {
  slot: PauseSlot
  slots: PauseSlot[]
  meditationDurationSeconds: number
  lobbyDurationSeconds: number
  canDelete: boolean
}) {
  const qc = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState<SlotForm>(slot)
  const [error, setError] = useState<string | null>(null)

  const invalidate = () => qc.invalidateQueries({ queryKey: ['pause-slots'] })

  const save = useMutation({
    mutationFn: () => updatePauseSlot(slot.id, form),
    onSuccess: () => {
      setEditing(false)
      setError(null)
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: () => deletePauseSlot(slot.id),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const handleSave = () => {
    // Validated against the day as this edit would leave it, which is the only
    // set any of these rules can be judged on.
    const next = slots.map((s) => (s.id === slot.id ? form : s))
    const problems = scheduleProblems(next, meditationDurationSeconds)
    if (problems.length > 0) {
      setError(problems.join(' '))
      return
    }
    setError(null)
    save.mutate()
  }

  const shown: SlotForm = editing ? form : slot
  const window = describeWindow(shown, meditationDurationSeconds)
  const set = describeSet(shown, lobbyDurationSeconds)

  const timeCell = (key: keyof SlotForm) =>
    editing ? (
      <input
        className="mono"
        value={form[key]}
        onChange={(e) => setForm((prev) => ({ ...prev, [key]: e.target.value }))}
      />
    ) : (
      <span className="mono">{slot[key]}</span>
    )

  return (
    <tr>
      <td>{timeCell('lobbyStart')}</td>
      <td>{timeCell('welcomeStart')}</td>
      <td>{timeCell('meditationStart')}</td>
      <td>{timeCell('windowEnd')}</td>
      <td>
        {window && (
          <div className="field-hint">
            <strong>Meditation</strong> <span className="mono">{window.meditation}</span>
            <br />
            <strong>Feedback</strong> <span className="mono">{window.feedback}</span>
            {set && (
              <>
                <br />
                <strong>Fuku&apos;s set</strong>{' '}
                <span className="mono">{set.window}</span>
                {set.overruns &&
                  ` — runs past the welcome at ${shown.welcomeStart}, so the app cuts it off there.`}
              </>
            )}
          </div>
        )}
        {error && <div className="error-banner">{error}</div>}
      </td>
      <td>
        <PendingBadge pending={slot.pending} />
      </td>
      <td>
        <div className="row-actions">
          {editing ? (
            <>
              <button className="btn btn-sm" onClick={handleSave} disabled={save.isPending}>
                Save
              </button>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => {
                  setEditing(false)
                  setForm(slot)
                  setError(null)
                }}
              >
                Cancel
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setEditing(true)}>
              Edit
            </button>
          )}
          <button
            className="btn btn-danger btn-sm"
            disabled={!canDelete || remove.isPending}
            title={
              canDelete
                ? undefined
                : 'The Global Pause needs at least one session time.'
            }
            onClick={() => {
              if (confirm(`Delete ${slotName(slot)}?`)) remove.mutate()
            }}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  )
}

function SessionTimesPanel() {
  const qc = useQueryClient()
  const { data: config } = useQuery({
    queryKey: ['pause-config'],
    queryFn: () => getPauseConfig(),
  })
  const { data, isLoading, error } = useQuery({
    queryKey: ['pause-slots'],
    queryFn: () => listPauseSlots(),
  })

  const [draft, setDraft] = useState<SlotForm>(EMPTY_SLOT)
  const [formError, setFormError] = useState<string | null>(null)

  const create = useMutation({
    mutationFn: () => createPauseSlot(draft),
    onSuccess: () => {
      setDraft(EMPTY_SLOT)
      setFormError(null)
      qc.invalidateQueries({ queryKey: ['pause-slots'] })
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const handleCreate = (e: FormEvent) => {
    e.preventDefault()
    const problems = scheduleProblems(
      [...(data ?? []), draft],
      config?.meditationDurationSeconds ?? 0
    )
    if (problems.length > 0) {
      setFormError(problems.join(' '))
      return
    }
    setFormError(null)
    create.mutate()
  }

  const field = (key: keyof SlotForm, label: string, placeholder: string) => (
    <div className="field">
      <label>{label}</label>
      <input
        className="mono"
        value={draft[key]}
        onChange={(e) => setDraft((prev) => ({ ...prev, [key]: e.target.value }))}
        placeholder={placeholder}
        required
      />
    </div>
  )

  return (
    <div className="panel">
      <div className="panel-title">Session times</div>
      <div className="field-hint">
        Each one runs every day, in the timezone above. Sessions cannot overlap,
        and there must always be at least one.
      </div>
      {formError && <div className="error-banner">{formError}</div>}
      <form className="inline-form" onSubmit={handleCreate}>
        {field('lobbyStart', 'Lobby start', '08:00:00')}
        {field('welcomeStart', 'Welcome start', '08:09:50')}
        {field('meditationStart', 'Meditation start', '08:10:00')}
        {field('windowEnd', 'Window end', '08:30:00')}
        <button className="btn" type="submit" disabled={create.isPending}>
          Add session
        </button>
      </form>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Lobby</th>
                <th>Welcome</th>
                <th>Meditation</th>
                <th>Window end</th>
                <th>Derived</th>
                <th>Status</th>
                <th style={{ width: 220 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((slot) => (
                <SlotRow
                  key={slot.id}
                  slot={slot}
                  slots={data!}
                  meditationDurationSeconds={config?.meditationDurationSeconds ?? 0}
                  lobbyDurationSeconds={config?.lobbyDurationSeconds ?? 0}
                  canDelete={data!.length > 1}
                />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={7} className="empty">
                    No session times yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function WelcomeMessageRow({
  message,
  index,
  count,
  onMove,
}: {
  message: PauseWelcomeMessage
  index: number
  count: number
  onMove: (index: number, dir: -1 | 1) => void
}) {
  const qc = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [text, setText] = useState(message.text)
  const [error, setError] = useState<string | null>(null)

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['pause-welcome-messages'] })
  }

  const save = useMutation({
    mutationFn: () => updatePauseWelcomeMessage(message.id, { text }),
    onSuccess: () => {
      setEditing(false)
      setError(null)
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const toggleActive = useMutation({
    mutationFn: () =>
      updatePauseWelcomeMessage(message.id, { isActive: !message.isActive }),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: () => deletePauseWelcomeMessage(message.id),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <tr>
      <td>
        {editing ? (
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Welcome message"
          />
        ) : (
          <span className={message.isActive ? '' : 'muted'}>{message.text}</span>
        )}
        {error && <div className="error-banner">{error}</div>}
      </td>
      <td>
        {message.isActive ? (
          <span className="badge badge-role">Visible</span>
        ) : (
          <span className="muted">Hidden</span>
        )}
        <PendingBadge pending={message.pending} />
      </td>
      <td>
        <div className="row-actions">
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === 0}
            onClick={() => onMove(index, -1)}
            title="Move up"
          >
            ↑
          </button>
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === count - 1}
            onClick={() => onMove(index, 1)}
            title="Move down"
          >
            ↓
          </button>
          {editing ? (
            <>
              <button
                className="btn btn-sm"
                onClick={() => save.mutate()}
                disabled={save.isPending}
              >
                Save
              </button>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => {
                  setEditing(false)
                  setText(message.text)
                  setError(null)
                }}
              >
                Cancel
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setEditing(true)}>
              Edit
            </button>
          )}
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => toggleActive.mutate()}
            disabled={toggleActive.isPending}
          >
            {message.isActive ? 'Hide' : 'Show'}
          </button>
          <button
            className="btn btn-danger btn-sm"
            onClick={() => {
              if (confirm('Delete this welcome message?')) remove.mutate()
            }}
            disabled={remove.isPending}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  )
}

function WelcomeMessagesPanel() {
  const qc = useQueryClient()
  const { data, isLoading, error } = useQuery({
    queryKey: ['pause-welcome-messages'],
    queryFn: () => listPauseWelcomeMessages(),
  })

  const [text, setText] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: ['pause-welcome-messages'] })

  const create = useMutation({
    mutationFn: () =>
      createPauseWelcomeMessage({ text, displayOrder: data?.length ?? 0 }),
    onSuccess: () => {
      setText('')
      setFormError(null)
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderPauseWelcomeMessages(ids),
    onSuccess: invalidate,
  })

  const handleCreate = (e: FormEvent) => {
    e.preventDefault()
    create.mutate()
  }

  const handleMove = (index: number, dir: -1 | 1) => {
    if (!data) return
    const ids = moveItem(data.map((m) => m.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  return (
    <div className="panel">
      <div className="panel-title">Welcome messages</div>
      <div className="field-hint">
        Shown before every session of the day, so keep them free of a time of day.
      </div>
      {formError && <div className="error-banner">{formError}</div>}
      <form className="inline-form" onSubmit={handleCreate}>
        <div className="field">
          <label>Text</label>
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Welcome. The world is about to pause together."
            required
          />
        </div>
        <button className="btn" type="submit" disabled={create.isPending}>
          Add message
        </button>
      </form>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Text</th>
                <th>Status</th>
                <th style={{ width: 380 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((m, i) => (
                <WelcomeMessageRow
                  key={m.id}
                  message={m}
                  index={i}
                  count={data!.length}
                  onMove={handleMove}
                />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={3} className="empty">
                    No welcome messages yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function IntentionRow({
  intention,
  index,
  count,
  onMove,
}: {
  intention: PauseIntentionOption
  index: number
  count: number
  onMove: (index: number, dir: -1 | 1) => void
}) {
  const qc = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [key, setKey] = useState(intention.key)
  const [label, setLabel] = useState(intention.label)
  const [error, setError] = useState<string | null>(null)

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['pause-intentions'] })
  }

  const save = useMutation({
    mutationFn: () => updatePauseIntention(intention.id, { key, label }),
    onSuccess: () => {
      setEditing(false)
      setError(null)
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const toggleActive = useMutation({
    mutationFn: () =>
      updatePauseIntention(intention.id, { isActive: !intention.isActive }),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: () => deletePauseIntention(intention.id),
    onSuccess: invalidate,
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <tr>
      <td>
        {editing ? (
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Label"
          />
        ) : (
          <span className={intention.isActive ? '' : 'muted'}>
            {intention.label}
          </span>
        )}
        {error && <div className="error-banner">{error}</div>}
      </td>
      <td className="mono">
        {editing ? (
          <input value={key} onChange={(e) => setKey(e.target.value)} placeholder="key" />
        ) : (
          intention.key
        )}
      </td>
      <td>
        {intention.isActive ? (
          <span className="badge badge-role">Visible</span>
        ) : (
          <span className="muted">Hidden</span>
        )}
        <PendingBadge pending={intention.pending} />
      </td>
      <td>
        <div className="row-actions">
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === 0}
            onClick={() => onMove(index, -1)}
            title="Move up"
          >
            ↑
          </button>
          <button
            className="btn btn-ghost btn-icon"
            disabled={index === count - 1}
            onClick={() => onMove(index, 1)}
            title="Move down"
          >
            ↓
          </button>
          {editing ? (
            <>
              <button
                className="btn btn-sm"
                onClick={() => save.mutate()}
                disabled={save.isPending}
              >
                Save
              </button>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => {
                  setEditing(false)
                  setKey(intention.key)
                  setLabel(intention.label)
                  setError(null)
                }}
              >
                Cancel
              </button>
            </>
          ) : (
            <button className="btn btn-ghost btn-sm" onClick={() => setEditing(true)}>
              Edit
            </button>
          )}
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => toggleActive.mutate()}
            disabled={toggleActive.isPending}
          >
            {intention.isActive ? 'Hide' : 'Show'}
          </button>
          <button
            className="btn btn-danger btn-sm"
            onClick={() => {
              if (confirm(`Delete intention "${intention.label}"?`)) remove.mutate()
            }}
            disabled={remove.isPending}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  )
}

function IntentionsPanel() {
  const qc = useQueryClient()
  const { data, isLoading, error } = useQuery({
    queryKey: ['pause-intentions'],
    queryFn: () => listPauseIntentions(),
  })

  const [key, setKey] = useState('')
  const [label, setLabel] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: ['pause-intentions'] })

  const create = useMutation({
    mutationFn: () =>
      createPauseIntention({ key, label, displayOrder: data?.length ?? 0 }),
    onSuccess: () => {
      setKey('')
      setLabel('')
      setFormError(null)
      invalidate()
    },
    onError: (e) => setFormError(apiErrorMessage(e)),
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderPauseIntentions(ids),
    onSuccess: invalidate,
  })

  const handleCreate = (e: FormEvent) => {
    e.preventDefault()
    create.mutate()
  }

  const handleMove = (index: number, dir: -1 | 1) => {
    if (!data) return
    const ids = moveItem(data.map((i) => i.id), index, dir)
    if (ids) reorder.mutate(ids)
  }

  return (
    <div className="panel">
      <div className="panel-title">Intentions</div>
      {formError && <div className="error-banner">{formError}</div>}
      <form className="inline-form" onSubmit={handleCreate}>
        <div className="field">
          <label>Key</label>
          <input
            value={key}
            onChange={(e) => setKey(e.target.value)}
            placeholder="calm"
            required
          />
        </div>
        <div className="field">
          <label>Label</label>
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Calm"
            required
          />
        </div>
        <button className="btn" type="submit" disabled={create.isPending}>
          Add intention
        </button>
      </form>

      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}

      {isLoading ? (
        <div className="state">Loading…</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Label</th>
                <th>Key</th>
                <th>Status</th>
                <th style={{ width: 380 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map((intention, i) => (
                <IntentionRow
                  key={intention.id}
                  intention={intention}
                  index={i}
                  count={data!.length}
                  onMove={handleMove}
                />
              ))}
              {data && data.length === 0 && (
                <tr>
                  <td colSpan={4} className="empty">
                    No intentions yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function PauseSettingsPage() {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Schedule</h1>
          <div className="page-subtitle">
            Global Pause session times, the audio and welcome copy they share,
            and the intentions offered afterwards. Changes here reach every user
            at once, so they publish explicitly.
          </div>
        </div>
      </div>

      <div className="stack">
        <ConfigPanel />
        <SessionTimesPanel />
        <WelcomeMessagesPanel />
        <IntentionsPanel />
      </div>
    </div>
  )
}

export default PauseSettingsPage
