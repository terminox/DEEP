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
      // PROTOTYPE — `-growthPassportPrototype` boots straight into the Growth
      // Passport variants for quick simulator QA. Throwaway.
      if ProcessInfo.processInfo.arguments.contains("-growthPassportPrototype") {
        GrowthPassportPrototypeView(canClose: false)
      } else {
        AppRootView()
      }
      #else
      AppRootView()
      #endif
    }
  }
}
