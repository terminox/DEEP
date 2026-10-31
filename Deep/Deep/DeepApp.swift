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
      // `AppRootView` gates first-run onboarding vs. the main tab shell and
      // owns the app-lifetime stores. It manages safe-area insets per branch
      // (onboarding screens inset themselves; the tab shell ignores them).
      #if DEBUG
      // PROTOTYPE — `-eegArtPrototype` boots straight into the EEG art
      // variants (Muse 2 simulated) for simulator QA. Throwaway.
      if ProcessInfo.processInfo.arguments.contains("-eegArtPrototype") {
        EEGArtPrototypeView()
      } else {
        AppRootView()
      }
      #else
      AppRootView()
      #endif
    }
  }
}
