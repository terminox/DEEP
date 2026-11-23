#if EXPERIMENTS
// Build-time checks for the Muse 2 SDK (LibMuse), which is gitignored and unpacked by
// `scripts/setup-muse-sdk.sh` (see Deep/Config/Muse.xcconfig).

// The TestFlight lab build exists to talk to a real headband: never ship one without it.
#if TESTFLIGHT && !targetEnvironment(simulator) && !MUSE_SDK
#error("The TestFlight lab build needs LibMuse. Run scripts/setup-muse-sdk.sh, then clean the build folder.")
#endif

// MuseSDK.local.xcconfig is there but the framework it points at is not.
#if MUSE_SDK && !canImport(Muse)
#error("MUSE_SDK is set but Muse.framework is missing. Run scripts/setup-muse-sdk.sh again.")
#endif

#if MUSE_SDK
import Muse

enum MuseSDK {
  /// LibMuse's own version string, for the diagnostics report.
  static var version: String { IXNLibmuseVersion.instance()?.getString() ?? "unknown" }
}
#endif
#endif
