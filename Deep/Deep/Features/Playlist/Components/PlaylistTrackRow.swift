import SwiftUI

/// One saved sound: the artwork of the collection it came from, its title, that
/// collection's name, and how long it runs. The frosted-card list row Deep
/// already uses for collections (`CollectionListView`), sized down for a track.
///
/// Taking a sound out lives in the long-press menu, the same gesture that
/// saved it — so the row itself carries nothing but the sound.
struct PlaylistTrackRow: View {
  let entry: PlaylistEntry
  /// True while this is the sound playing, which tints the title the way a
  /// collection's track list does.
  let isCurrent: Bool
  let isLocked: Bool
  let play: () -> Void
  let remove: () -> Void

  var body: some View {
    Button(action: play) {
      HStack(spacing: 14) {
        SoundArtwork(
          palette: entry.collection.palette,
          imageURL: entry.collection.imageURL,
          cornerRadius: 14
        )
        .frame(width: 56, height: 56)

        VStack(alignment: .leading, spacing: 3) {
          Text(entry.track.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(isCurrent ? Color.lavenderMist : .deepPlum)
            .lineLimit(1)
          Text(entry.collection.title)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
          Text(entry.track.duration.clockString)
            .font(DeepType.micro)
            .monospacedDigit()
            .foregroundStyle(.driftGrey)
        }
        // A Spacer here would bid against this column and truncate titles that
        // had room; a greedy frame lets the text take what it needs.
        .frame(maxWidth: .infinity, alignment: .leading)

        if isLocked {
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundStyle(.driftGrey)
        }
      }
      .padding(12)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    // No `.destructive` role: it would paint this the system's alarm red, and
    // Deep has no urgent reds. Taking a sound out is one tap from saving it
    // again.
    .contextMenu {
      Button(action: remove) {
        Label("Remove from playlist", systemImage: "bookmark.slash")
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(entry.track.title), from \(entry.collection.title)")
  }
}

#Preview("Playlist row") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 14) {
      PlaylistTrackRow(
        entry: PlaylistFixtures.saved.entries[0],
        isCurrent: false,
        isLocked: false,
        play: {},
        remove: {}
      )
      PlaylistTrackRow(
        entry: PlaylistFixtures.saved.entries[1],
        isCurrent: true,
        isLocked: false,
        play: {},
        remove: {}
      )
      PlaylistTrackRow(
        entry: PlaylistFixtures.saved.entries[2],
        isCurrent: false,
        isLocked: true,
        play: {},
        remove: {}
      )
    }
    .padding(.horizontal, .edge)
  }
}
