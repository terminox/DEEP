//
//  DeepApp.swift
//  Deep
//
//  Created by Yossa Bourne on 5/26/26.
//

import SwiftUI

@main
struct DeepApp: App {
  /// Answers which orientations DEEP may use (portrait, except where a screen
  /// asks for more through `OrientationLock`).
  @UIApplicationDelegateAdaptor(DeepAppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      #if DEBUG && EXPERIMENTS
      // QA and recordings: `-experiment demo.lantern` (or sit.aurora, …) opens one
      // straight away, no account needed.
      if let launch = ExperimentLaunch.fromLaunchArguments {
        launch.destination
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
