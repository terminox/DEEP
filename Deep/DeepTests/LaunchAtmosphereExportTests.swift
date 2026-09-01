import Testing
import SwiftUI
import UIKit
import Foundation
@testable import Deep

/// Regenerates the launch screen's stills from the live `AtmosphereBackground`.
///
/// A launch screen runs no code — no gradient layer, no blur — so the atmosphere
/// has to ship as flat images. Rendering them here, through SwiftUI's own
/// rasterizer and off the same `Orb` specs and `DeepTheme` tokens the live view
/// draws from, keeps the launch screen from drifting into a hand-tuned
/// lookalike: change a palette entry or an orb's offset and re-running this puts
/// the launch screen back in step.
///
/// It writes into the repo, so it is skipped on a normal test run and only fires
/// when asked for by name:
///
///     TEST_RUNNER_EXPORT_LAUNCH_ASSETS=1 xcodebuild test \
///       -scheme Deep -destination 'platform=iOS Simulator,id=<udid>' \
///       -only-testing:DeepTests/LaunchAtmosphereExportTests
///
/// (`xcodebuild` forwards host environment variables prefixed `TEST_RUNNER_`
/// into the test process with the prefix stripped.)
@MainActor
struct LaunchAtmosphereExportTests {
  /// The gradient ships as a tall, narrow strip: it is flat horizontally, and
  /// the storyboard stretches it to the screen. Its stops are proportional, so
  /// one strip is correct at every screen height.
  private static let gradientSize = CGSize(width: 4, height: 2000)

  /// Asset names, in `AtmosphereBackground.orbs` order.
  private static let orbAssetNames = ["LaunchOrbLavender", "LaunchOrbBlush", "LaunchOrbSky"]
  private static let gradientAssetName = "LaunchAtmosphereGradient"

  @Test(.enabled(if: ProcessInfo.processInfo.environment["EXPORT_LAUNCH_ASSETS"] == "1"))
  func exportsLaunchAtmosphereStills() throws {
    // The gradient is flattened over moonCream, because that is what the app
    // actually shows: the wash's lower stops are translucent and always sit on
    // the moonCream backdrop `AppRootView` paints beneath them. Exported bare it
    // would read washed out against the real first frame.
    try write(
      ZStack {
        Color.moonCream
        AtmosphereBackground.sky
      }
      .frame(width: Self.gradientSize.width, height: Self.gradientSize.height),
      to: Self.gradientAssetName,
      opaque: true
    )

    for (orb, name) in zip(AtmosphereBackground.orbs, Self.orbAssetNames) {
      try write(orb.still, to: name, opaque: false)
    }
  }

  /// Renders `content` at scale 1 and replaces the named imageset's PNG.
  ///
  /// Scale 1 is ample even on a 3x screen: the sharpest detail in a 60–70pt
  /// gaussian is some thirty times coarser than the sampling grid, so the
  /// upscale is invisible — and it keeps the committed PNGs small.
  private func write(_ content: some View, to assetName: String, opaque: Bool) throws {
    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    renderer.isOpaque = opaque

    let image = try #require(renderer.uiImage, "ImageRenderer produced no image for \(assetName)")
    let data = try #require(image.pngData(), "no PNG data for \(assetName)")

    let imageset = Self.catalogURL.appendingPathComponent("\(assetName).imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
    try data.write(to: imageset.appendingPathComponent("\(assetName).png"))
    try Self.contentsJSON(filename: "\(assetName).png")
      .write(to: imageset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    print("exported \(assetName).png — \(Int(image.size.width))×\(Int(image.size.height))pt, \(data.count) bytes")
  }

  /// A single universal, single-scale entry — the shape `OnboardingLogo` uses.
  private static func contentsJSON(filename: String) -> String {
    """
    {
      "images" : [
        {
          "filename" : "\(filename)",
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
  }

  /// The app's asset catalog in the working tree, found from this file's own
  /// path — the simulator has no notion of where the repo lives.
  private static var catalogURL: URL {
    URL(fileURLWithPath: #filePath)      // …/Deep/DeepTests/LaunchAtmosphereExportTests.swift
      .deletingLastPathComponent()       // …/Deep/DeepTests
      .deletingLastPathComponent()       // …/Deep
      .appendingPathComponent("Deep/Assets.xcassets", isDirectory: true)
  }
}
