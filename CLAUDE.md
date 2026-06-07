# CLAUDE.md

Project-specific guidance for the Deep iOS app.

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
- **Keep styling minimal in coordinator views.** A coordinator composes screens and wires
  navigation / tabs / state; it should carry as little visual styling as possible. Screen-level
  styling (backgrounds, atmospheres, etc.) belongs in the leaf screens it routes to. Otherwise a
  background placed in the coordinator can end up hidden behind the navigation or tab container
  and never render — as happened in an earlier `DeepSoundView`, where `AtmosphereBackground` sat
  behind the `NavigationStack` and was invisible.

## Naming

- **Never name types after their role-in-the-pattern.** Do not use `…Protocol` for protocols, nor
  `…Impl` / `…ProtocolImpl` / `…Default` for the concrete conformer. These names convey nothing
  about behaviour — they're a widespread anti-pattern. Name the protocol for the *capability* and
  the conformers for *what they concretely are*. For example: a `SoundPlaying` protocol with a
  real `SoundPlayer` and a `MockSoundPlayer` — never `SoundPlayerProtocol` + `SoundPlayerImpl`.
