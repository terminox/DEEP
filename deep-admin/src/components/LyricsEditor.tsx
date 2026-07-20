import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { deleteLyrics, listLyrics, upsertLyrics } from '../api/endpoints'
import { apiErrorMessage } from '../api/errors'

const NEW = '__new__'

type Props = {
  trackId: string
  onChanged: () => void
}

export function LyricsEditor({ trackId, onChanged }: Props) {
  const qc = useQueryClient()
  const [selected, setSelected] = useState<string | null>(null)
  const [languageCode, setLanguageCode] = useState('')
  const [content, setContent] = useState('')
  const [error, setError] = useState<string | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['lyrics', trackId],
    queryFn: () => listLyrics(trackId),
  })

  // Default to the first language when lyrics load and nothing is selected.
  useEffect(() => {
    if (selected === null && data && data.length > 0) {
      const first = data[0]
      setSelected(first.languageCode)
      setLanguageCode(first.languageCode)
      setContent(first.content)
    }
  }, [data, selected])

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['lyrics', trackId] })
    onChanged()
  }

  const selectLang = (code: string) => {
    const entry = data?.find((l) => l.languageCode === code)
    setSelected(code)
    setLanguageCode(code)
    setContent(entry?.content ?? '')
    setError(null)
  }

  const startNew = () => {
    setSelected(NEW)
    setLanguageCode('')
    setContent('')
    setError(null)
  }

  const save = useMutation({
    mutationFn: () => upsertLyrics(trackId, languageCode.trim(), content),
    onSuccess: () => {
      setSelected(languageCode.trim())
      setError(null)
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  const remove = useMutation({
    mutationFn: (code: string) => deleteLyrics(trackId, code),
    onSuccess: () => {
      setSelected(null)
      setLanguageCode('')
      setContent('')
      invalidate()
    },
    onError: (e) => setError(apiErrorMessage(e)),
  })

  return (
    <div style={{ marginTop: 12 }}>
      {error && <div className="error-banner">{error}</div>}

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
        {isLoading && <span className="muted">Loading lyrics…</span>}
        {data?.map((l) => (
          <button
            key={l.languageCode}
            type="button"
            className={`lang-chip${selected === l.languageCode ? ' active' : ''}`}
            onClick={() => selectLang(l.languageCode)}
          >
            {l.languageCode}
          </button>
        ))}
        <button
          type="button"
          className={`lang-chip${selected === NEW ? ' active' : ''}`}
          onClick={startNew}
        >
          + Add language
        </button>
      </div>

      {selected !== null && (
        <div>
          <div className="field" style={{ maxWidth: 220 }}>
            <label>Language code</label>
            <input
              value={languageCode}
              onChange={(e) => setLanguageCode(e.target.value)}
              placeholder="en, th, ja…"
              disabled={selected !== NEW}
            />
          </div>
          <div className="field">
            <label>Content</label>
            <textarea value={content} onChange={(e) => setContent(e.target.value)} />
          </div>
          <div className="form-actions">
            <button
              className="btn btn-sm"
              onClick={() => save.mutate()}
              disabled={save.isPending || !languageCode.trim()}
            >
              {selected === NEW ? 'Add lyrics' : 'Save lyrics'}
            </button>
            {selected !== NEW && (
              <button
                className="btn btn-danger btn-sm"
                onClick={() => {
                  if (confirm(`Delete ${selected} lyrics?`)) remove.mutate(selected)
                }}
                disabled={remove.isPending}
              >
                Delete language
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
