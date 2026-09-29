// An iPhone 17 Pro drawn in CSS around a real iOS capture. The screen is 402 × 874 pt, so a
// simulator recording (1206 × 2622, or any scale of it) fills it exactly.
import type { CSSProperties, ReactNode } from 'react'
import './IPhoneFrame.css'

export function IPhoneFrame({
  children,
  width,
  label,
}: {
  children: ReactNode
  /** Width of the whole device, any CSS length. Everything else scales from it. */
  width: string
  /** What the screen shows, for assistive tech. Without it the device is decorative. */
  label?: string
}) {
  return (
    <div
      className="iphone"
      style={{ '--iphone-w': width } as CSSProperties}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <span className="iphone-button iphone-button--action" />
      <span className="iphone-button iphone-button--up" />
      <span className="iphone-button iphone-button--down" />
      <span className="iphone-button iphone-button--power" />
      <div className="iphone-bezel">
        <div className="iphone-screen">
          {children}
          <span className="iphone-island" />
          <span className="iphone-glare" />
        </div>
      </div>
    </div>
  )
}
