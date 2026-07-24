# CLAUDE.md

Project-specific guidance for the Deep iOS app.

## Orchestration workflow
You (Fable) are the orchestrator. Plan, decompose, synthesize.
Reasoning-heavy phases → deep-reasoner
Mechanical work → fast-worker
Codex (/codex:rescue --background) is a cracked engineer on par with deep-reasoner, from a different perspective. Treat as a peer, not a reviewer.
High-stakes decisions: task Opus + Codex on the same problem in parallel, synthesize the best of both, without showing either the other's answer. Keep your own context lean.

## Git

Don't commit unless I explicitly tell you to do so.

## Testing on the simulator

- **Always use `baguette` for headless simulator control when testing.** Do not drive the
  Simulator app via AppleScript / System Events clicks. `baguette` (`/opt/homebrew/bin/baguette`)
  boots a simulator headlessly and sends real gestures by UDID:
  `baguette boot`, `baguette tap --udid <udid> --x <x> --y <y> --width <w> --height <h>`,
  plus `swipe`, `pinch`, `pan`, `press`, and `stream`. Use `baguette list` for UDIDs.
  Install/launch with `xcrun simctl <udid> install|launch` and capture with
  `xcrun simctl io <udid> screenshot`.

## Code style

- **Indentation: always 2 spaces per indent level (1 tab = 2 spaces). No tabs, no 4-space indents.**
  Applies to every Swift file in this project. When generating or editing code, emit 2-space indentation.
  If you encounter any file using a different indent width, reformat it to 2 spaces as part of your change.

## SwiftUI

- **Always add a `#Preview` when you create a new SwiftUI view.** Every new view ships with at
  least one preview.
- **Always mock dependencies in previews.** Inject fake / stub implementations into a view's
  previews — never wire up real or concrete dependencies (networking, players, stores, etc.)
  unless explicitly told otherwise. Previews must be hermetic and free of side effects.
- **Never put navigation containers directly inside an ordinary view.** This covers SwiftUI
  navigation and tab containers (`NavigationStack`, `NavigationSplitView`, `TabView`) and their
  UIKit equivalents (`UINavigationController`, `UITabBarController`, `UISplitViewController`), as
  well as any custom navigation/routing component. The only exception is a *coordinator view*:
  the composition root that owns navigation or tabs for one specific business flow. A coordinator
  must declare this in its name (e.g. `DeepSoundCoordinatorView`). Leaf screens receive
  navigation only through the coordinator — they never host the container themselves.
- **Never use `NavigationLink` with `NavigationStack`. Drive navigation through a
  `NavigationPath` instead.** The coordinator owns a single `@State private var path =
  NavigationPath()` and uses `NavigationStack(path:)` with `.navigationDestination(for:)`. It
  exposes a navigation action to its leaf screens — preferably via an environment value (e.g.
  `@Entry var openCollection: (SoundCollection) -> Void`, matching the design-token / `soundPlayer`
  injection style) — and the leaf taps a plain `Button` that calls that action to append to the
  path. Routing stays in one place (the path), is programmatically driveable (deep links, pop to
  root, back), and leaf screens never host a `NavigationLink`. See `DeepSoundCoordinatorView` and
  `CollectionTile` / `BreatheHeroCard` for the reference pattern.
- **Keep styling minimal in coordinator views.** A coordinator composes screens and wires
  navigation / tabs / state; it should carry as little visual styling as possible. Screen-level
  styling (backgrounds, atmospheres, etc.) belongs in the leaf screens it routes to. Otherwise a
  background placed in the coordinator can end up hidden behind the navigation or tab container
  and never render — as happened in an earlier `DeepSoundView`, where `AtmosphereBackground` sat
  behind the `NavigationStack` and was invisible.

## Design rules

- **Never use line separators.** No `Divider()`, no 1pt `Rectangle`/`Capsule` hairline rules
  (horizontal or vertical), no border strokes used as row or section separators — anywhere in
  the app. Separate content with spacing, grouping, and cards instead: adjust `VStack`/`HStack`
  spacing, split content into distinct frosted cards, or use background tint changes. If you
  encounter an existing separator while editing a view, remove it and rework the grouping as
  part of your change.

## Theming & design tokens

Design tokens (colours, motion, radii, spacing) follow one pattern. Reuse this principle on any
project:

- **One private source of truth.** Each token is declared exactly once as raw, framework-agnostic
  values (e.g. RGB components) inside a `private` palette/scale type. No raw literal (an RGB
  triple, a duration, a radius number) ever appears anywhere else in the codebase.
- **Native types are thin projections.** The source token materialises into the framework-native
  type(s) it's consumed as — a SwiftUI `Color` *and* a UIKit `UIColor` from the same entry — so a
  token reads identically across layers and can never drift between them.
- **Expose tokens as first-class, dot-accessible values.** Surface each token by extending the
  type the call site already expects, so it reads like a built-in: `ShapeStyle where Self == Color`
  for colours (`.fill(.blushPowder)`, `Color.deepPlum`), `UIColor` for UIKit
  (`tabBar.tintColor = .lavenderMist`), `Animation` for motion (`.animation(.exhale, value:)`),
  `CGFloat` for radii and spacing (`RoundedRectangle(cornerRadius: .card)`,
  `.padding(.horizontal, .edge)`). Never expose a bag of constants like `Theme.colorPrimary`.
- **Name tokens for meaning, not appearance or value.** Prefer semantic/poetic names tied to the
  design language (`lavenderMist`, `exhale`, `card`, `edge`) over literal descriptions
  (`lightPurple`, `animation800ms`, `radius24`), so a value can change without the name lying.
- **Group by role with `MARK:` sections** (palette, SwiftUI colours, UIKit colours, motion, radii,
  spacing) so the file stays the single, scannable map of the project's visual language.

## Naming

- **Never name types after their role-in-the-pattern.** Do not use `…Protocol` for protocols, nor
  `…Impl` / `…ProtocolImpl` / `…Default` for the concrete conformer. These names convey nothing
  about behaviour — they're a widespread anti-pattern. Name the protocol for the *capability* and
  the conformers for *what they concretely are*. For example: a `SoundPlaying` protocol with a
  real `SoundPlayer` and a `MockSoundPlayer` — never `SoundPlayerProtocol` + `SoundPlayerImpl`.
