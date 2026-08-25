import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  createPauseIntention,
  createPauseWelcomeMessage,
  deletePauseIntention,
  deletePauseWelcomeMessage,
  getPauseConfig,
  listPauseIntentions,
  listPauseWelcomeMessages,
  reorderPauseIntentions,
  reorderPauseWelcomeMessages,
  updatePauseConfig,
  updatePauseIntention,
  updatePauseWelcomeMessage,
  uploadMedia,
} from '../api/endpoints'
import type { PauseIntentionOption, PauseWelcomeMessage } from '../api/types'
import { apiErrorMessage } from '../api/errors'
import { moveItem } from '../lib/reorder'
import { MediaDropzone } from '../components/MediaDropzone'

type ConfigForm = {
  timezone: string
  lobbyStart: string
  welcomeStart: string
  meditationStart: string
  feedbackStart: string
  windowEnd: string
  lobbyAudioPath: string
  meditationAudioPath: string
  meditationDurationSeconds: string
}

const TIME_RE = /^\d{2}:\d{2}:\d{2}$/

// Mirrors the server rule: valid HH:mm:ss values, strictly increasing.
function validateConfig(form: ConfigForm): string | null {
  const phases: [string, string][] = [
    ['Lobby start', form.lobbyStart],
    ['Welcome start', form.welcomeStart],
    ['Meditation start', form.meditationStart],
    ['Feedback start', form.feedbackStart],
    ['Window end', form.windowEnd],
  ]
  for (const [label, value] of phases) {
    if (!TIME_RE.test(value)) return `${label} must be HH:mm:ss`
  }
  const order = phases.map(([, value]) => value)
  if (!order.every((t, i) => i === 0 || order[i - 1] < t)) {
    return 'Phase times must be strictly increasing'
  }
  const duration = Number(form.meditationDurationSeconds)
  if (!Number.isInteger(duration) || duration <= 0) {
    return 'Meditation duration must be a positive whole number of seconds'
  }
  return null
}

// Parses an HH:mm:ss value into seconds since local midnight, per TIME_RE.
function timeToSeconds(time: string): number | null {
  if (!TIME_RE.test(time)) return null
  const [h, m, s] = time.split(':').map(Number)
  return h * 3600 + m * 60 + s
}

// Formats seconds since local midnight back into the HH:mm:ss shape the
// other time fields use.
function secondsToTime(totalSeconds: number): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  const h = Math.floor(totalSeconds / 3600)
  const m = Math.floor((totalSeconds % 3600) / 60)
  const s = totalSeconds % 60
  return `${pad(h)}:${pad(m)}:${pad(s)}`
}

type WindowMismatch = {
  meditationStart: string
  feedbackStart: string
  windowSeconds: number
  duration: number
  correctedFeedbackStart: string
}

// The meditation phase runs meditationStart -> feedbackStart; that span
// should equal meditationDurationSeconds, or a mid-window join seeks past
// end-of-file. Non-blocking - a different cut of the window may be
// intentional, so this only informs, it never validates.
function computeWindowMismatch(form: ConfigForm): WindowMismatch | null {
  const start = timeToSeconds(form.meditationStart)
  const end = timeToSeconds(form.feedbackStart)
  const duration = Number(form.meditationDurationSeconds)
  if (start == null || end == null || !Number.isInteger(duration) || duration <= 0) {
    return null
  }
  const windowSeconds = end - start
  if (windowSeconds === duration) return null
  return {
    meditationStart: form.meditationStart,
    feedbackStart: form.feedbackStart,
    windowSeconds,
    duration,
    correctedFeedbackStart: secondsToTime(start + duration),
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
        lobbyStart: data.lobbyStart,
        welcomeStart: data.welcomeStart,
        meditationStart: data.meditationStart,
        feedbackStart: data.feedbackStart,
        windowEnd: data.windowEnd,
        lobbyAudioPath: data.lobbyAudioPath,
        meditationAudioPath: data.meditationAudioPath,
        meditationDurationSeconds: String(data.meditationDurationSeconds),
        ...edits,
      }
    : null

  const windowMismatch = form ? computeWindowMismatch(form) : null

  const save = useMutation({
    mutationFn: (body: ConfigForm) =>
      updatePauseConfig({
        timezone: body.timezone,
        lobbyStart: body.lobbyStart,
        welcomeStart: body.welcomeStart,
        meditationStart: body.meditationStart,
        feedbackStart: body.feedbackStart,
        windowEnd: body.windowEnd,
        lobbyAudioPath: body.lobbyAudioPath,
        meditationAudioPath: body.meditationAudioPath,
        meditationDurationSeconds: Number(body.meditationDurationSeconds),
      }),
    onSuccess: () => {
      setEdits({})
      setFormError(null)
      setSaved(true)
      qc.invalidateQueries({ queryKey: ['pause-config'] })
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
    const validationError = validateConfig(form)
    if (validationError) {
      setSaved(false)
      setFormError(validationError)
      return
    }
    setFormError(null)
    save.mutate(form)
  }

  return (
    <div className="panel">
      <div className="panel-title">Schedule &amp; audio</div>
      {error && <div className="error-banner">{apiErrorMessage(error)}</div>}
      {formError && <div className="error-banner">{formError}</div>}
      {saved && <div className="success-banner">Configuration saved.</div>}
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
                required
              />
            </div>
          </div>
          <div className="form-row">
            <div className="field">
              <label>Lobby start</label>
              <input
                className="mono"
                value={form.lobbyStart}
                onChange={(e) => update({ lobbyStart: e.target.value })}
                placeholder="20:30:00"
                required
              />
            </div>
            <div className="field">
              <label>Welcome start</label>
              <input
                className="mono"
                value={form.welcomeStart}
                onChange={(e) => update({ welcomeStart: e.target.value })}
                placeholder="20:39:50"
                required
              />
            </div>
            <div className="field">
              <label>Meditation start</label>
              <input
                className="mono"
                value={form.meditationStart}
                onChange={(e) => update({ meditationStart: e.target.value })}
                placeholder="20:40:00"
                required
              />
            </div>
          </div>
          <div className="form-row">
            <div className="field">
              <label>Feedback start</label>
              <input
                className="mono"
                value={form.feedbackStart}
                onChange={(e) => update({ feedbackStart: e.target.value })}
                placeholder="20:50:00"
                required
              />
            </div>
            <div className="field">
              <label>Window end</label>
              <input
                className="mono"
                value={form.windowEnd}
                onChange={(e) => update({ windowEnd: e.target.value })}
                placeholder="21:00:00"
                required
              />
            </div>
          </div>
          {windowMismatch && (
            <div className="warning-banner">
              Meditation window ({windowMismatch.meditationStart}–{windowMismatch.feedbackStart}) is{' '}
              {windowMismatch.windowSeconds}s, but the duration field is set to{' '}
              {windowMismatch.duration}s.{' '}
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() =>
                  update({ feedbackStart: windowMismatch.correctedFeedbackStart })
                }
              >
                Set feedback start to match
              </button>
            </div>
          )}
          <MediaDropzone
            label="Lobby audio"
            kind="audio"
            currentUrl={form.lobbyAudioPath || null}
            onUpload={async (file, onProgress) => {
              const media = await uploadMedia('audio', file, onProgress)
              update({ lobbyAudioPath: media.path })
            }}
            urlInput={{
              value: form.lobbyAudioPath,
              onChange: (v) => update({ lobbyAudioPath: v }),
              placeholder: '/media/audio/global-pause.mp3',
            }}
          />
          <MediaDropzone
            label="Meditation audio"
            kind="audio"
            currentUrl={form.meditationAudioPath || null}
            onUpload={async (file, onProgress) => {
              const media = await uploadMedia('audio', file, onProgress)
              update({ meditationAudioPath: media.path })
            }}
            onDurationDetected={(seconds) =>
              update({ meditationDurationSeconds: String(Math.round(seconds)) })
            }
            urlInput={{
              value: form.meditationAudioPath,
              onChange: (v) => update({ meditationAudioPath: v }),
              placeholder: '/media/audio/inner-light.mp3',
            }}
          />
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
          <span className="badge badge-role">Active</span>
        ) : (
          <span className="muted">Inactive</span>
        )}
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
            {message.isActive ? 'Deactivate' : 'Activate'}
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
      {formError && <div className="error-banner">{formError}</div>}
      <form className="inline-form" onSubmit={handleCreate}>
        <div className="field">
          <label>Text</label>
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Welcome to tonight's pause"
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
          <span className="badge badge-role">Active</span>
        ) : (
          <span className="muted">Inactive</span>
        )}
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
            {intention.isActive ? 'Deactivate' : 'Activate'}
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
          <h1>Pause Settings</h1>
          <div className="page-subtitle">
            Nightly Global Pause schedule, welcome messages and intentions
          </div>
        </div>
      </div>

      <div className="stack">
        <ConfigPanel />
        <WelcomeMessagesPanel />
        <IntentionsPanel />
      </div>
    </div>
  )
}

export default PauseSettingsPage
