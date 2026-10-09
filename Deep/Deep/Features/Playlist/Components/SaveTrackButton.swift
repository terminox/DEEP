import SwiftUI

/// The bookmark that saves a sound to the playlist, set in moonlight over Now
/// Playing's full-screen photograph.
///
/// A bookmark rather than a heart on purpose: `heart.fill` in blush is the
/// Compassion currency everywhere else in DEEP, and the same mark cannot mean
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
        .font(.system(size: 18, weight: .semibold))
        // Full cream when kept, the ink the track title wears, so the filled
        // mark reads as *more* present than the empty one, which steps back
        // to the subtitle's softer cream.
        .foregroundStyle(isSaved ? Color.moonCream : .moonCream.opacity(0.72))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 44, height: 44)
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
    Color.deepPlum.ignoresSafeArea()
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
