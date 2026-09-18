pluginManagement {
  repositories {
    google {
      content {
        includeGroupByRegex("com\\.android.*")
        includeGroupByRegex("com\\.google.*")
        includeGroupByRegex("androidx.*")
      }
    }
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
  }
}

rootProject.name = "Deep"

include(":app")

// Pure Kotlin/JVM — no Android dependency. Holds the logic the iOS test suite
// covers, so those suites port across and run in about a second. See its build
// file for why that is worth a module boundary.
include(":core:model")
