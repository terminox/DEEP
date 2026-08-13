//
//  DeepApp.swift
//  Deep
//
//  Created by Yossa Bourne on 5/26/26.
//

import SwiftUI

@main
struct DeepApp: App {
  #if DEBUG
  /// Flip to boot straight into the Earth tuning lab (see `EarthTuningLabView`)
  /// instead of the real app. Dev-only escape hatch — never ships true.
  private static let bootIntoEarthTuningLab = true
  #endif

  var body: some Scene {
    WindowGroup {
      // `AppRootView` gates first-run onboarding vs. the main tab shell and
      // owns the app-lifetime stores. It manages safe-area insets per branch
      // (onboarding screens inset themselves; the tab shell ignores them).
      #if DEBUG
      if Self.bootIntoEarthTuningLab {
        EarthTuningLabView()
      } else {
        AppRootView()
      }
      #else
      AppRootView()
      #endif
    }
  }
}
