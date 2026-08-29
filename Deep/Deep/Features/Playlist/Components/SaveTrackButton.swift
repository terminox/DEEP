import SwiftUI

/// The bookmark that saves a sound to the playlist — Now Playing's one
/// utility control, in the soft translucent circle the screen already draws.
///
/// A bookmark rather than a heart on purpose: `heart.fill` in blush is the
/// Compassion currency everywhere else in Deep, and the same mark cannot mean
/// two things.
struct SaveTrackButton: View {
  let track: SoundTrack
  /// Where the sound came from, kept alongside it so the playlist row can draw
  /// its artwork and name it.
  let collection: SoundCollection

  @Environment(\.playlistStore) private var store

  private var isSaved: Bool { store.isSaved(track) }

  var body: some View {
    Button {
      store.toggle(track, from: collection)
    } label: {
      Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
        .font(.system(.subheadline, weight: .semibold))
        // Plum when kept, the same ink this screen's transport wears, so the
        // filled mark reads as *more* present than the empty one. Lavender
        // would sink into Now Playing's own lavender wash and read as less.
        .foregroundStyle(isSaved ? Color.deepPlum : .driftGrey)
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 34, height: 34)
        .background(Circle().fill(.white.opacity(0.4)))
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .animation(.exhale, value: isSaved)
    .accessibilityLabel(isSaved ? "Saved to playlist" : "Save to playlist")
    .accessibilityHint(
      isSaved ? "Removes this sound from your playlist" : "Adds this sound to your playlist"
    )
  }
}

#Preview("Save track — saved and not") {
  ZStack {
    AtmosphereBackground()
    HStack(spacing: 24) {
      SaveTrackButton(
        track: PlaylistFixtures.saved.entries[0].track,
        collection: PlaylistFixtures.saved.entries[0].collection
      )
      .environment(\.playlistStore, .empty)

      SaveTrackButton(
        track: PlaylistFixtures.saved.entries[0].track,
        collection: PlaylistFixtures.saved.entries[0].collection
      )
      .environment(\.playlistStore, .sample)
    }
  }
}
