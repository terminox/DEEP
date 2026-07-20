import SwiftUI

/// The lyrics view for a track, opened from Now Playing. Fetches the track's
/// lyrics from the backend, offers a gentle language switch when more than one
/// language exists, and falls back to a calm empty state otherwise.
struct LyricsSheet: View {
  let track: SoundTrack

  @Environment(\.soundContentRepository) private var repository
  @Environment(\.dismiss) private var dismiss

  @State private var lyrics: [Lyrics] = []
  @State private var selected: String?
  @State private var isLoading = true

  private var current: Lyrics? {
    lyrics.first { $0.languageCode == selected } ?? lyrics.first
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .rhythm) {
        Text(track.title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)

        if lyrics.count > 1 {
          languagePicker
        }

        if isLoading {
          LoadingOrb()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let current {
          Text(current.content)
            .font(DeepType.body)
            .foregroundStyle(.deepPlum)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("No lyrics for this one — just let it wash over you.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.top, .rhythm)
      .padding(.bottom, 60)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task { await load() }
  }

  private var languagePicker: some View {
    HStack(spacing: 8) {
      ForEach(lyrics) { lyric in
        Button {
          withAnimation(.settle) { selected = lyric.languageCode }
        } label: {
          Text(lyric.languageCode.uppercased())
            .font(DeepType.micro)
            .foregroundStyle(selected == lyric.languageCode ? .deepPlum : .driftGrey)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
              Capsule().fill(.white.opacity(selected == lyric.languageCode ? 0.7 : 0.3))
            )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func load() async {
    isLoading = true
    let fetched = (try? await repository.lyrics(trackID: track.id, language: nil)) ?? []
    lyrics = fetched
    selected = fetched.first?.languageCode
    isLoading = false
  }
}

#Preview("Lyrics") {
  LyricsSheet(track: SoundLibrary.deepTeacher[0].tracks[0])
}
