package io.appbeyond.freelance.deep

import android.app.Application
import io.appbeyond.freelance.deep.networking.AppDependencies

/**
 * Process entry point. Owns the one composition root.
 *
 * Dependencies are built by hand rather than by an injection framework, matching
 * `AppDependencies.swift` on iOS. The graph is small, entirely constructor-wired,
 * and readable top to bottom — and skipping an annotation processor keeps the
 * build fast, which matters across eight weekly releases.
 */
class DeepApplication : Application() {

  lateinit var dependencies: AppDependencies
    private set

  override fun onCreate() {
    super.onCreate()
    dependencies = AppDependencies(this)
  }
}
