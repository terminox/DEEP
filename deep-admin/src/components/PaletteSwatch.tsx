import type { Palette } from '../api/types'

export function PaletteSwatch({ palette }: { palette: Palette }) {
  return (
    <span className="palette-swatch">
      <span className={`swatch-dot palette-${palette}`} />
      {palette}
    </span>
  )
}
