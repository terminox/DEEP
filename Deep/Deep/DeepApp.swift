//
//  DeepApp.swift
//  Deep
//
//  Created by Yossa Bourne on 5/26/26.
//

import SwiftUI

@main
struct DeepApp: App {
  var body: some Scene {
    WindowGroup {
      // THROWAWAY — `SIMCTL_CHILD_NOW_PLAYING_LAB=1` opens the full-screen
      // player lab straight away, skipping sign-in, with a fixture collection
      // playing. Delete this fence with `Features/DeepSound/NowPlayingLab/`.
      #if DEBUG
      if ProcessInfo.processInfo.environment["NOW_PLAYING_LAB"] == "1" {
        NowPlayingLabStandalone()
      } else {
        AppRootView()
      }
      #else
      // `AppRootView` gates first-run onboarding vs. the main tab shell and
      // owns the app-lifetime stores. It manages safe-area insets per branch
      // (onboarding screens inset themselves; the tab shell ignores them).
      AppRootView()
      #endif
    }
  }
}
