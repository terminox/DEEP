#if DEBUG
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// PROTOTYPE — throwaway. The one piece every variant shares: the printable
// Growth Passport (two A4 pages) and the sheet that previews and exports it.

/// Which parts of the portfolio page to print.
struct PassportSections: Equatable {
  var garden = true
  var practice = true
  var compassion = true
  var challenges = true
  var note = true
}

// MARK: - Print type

/// Print sizes. A4 is 595pt wide, so the phone's Dynamic Type scale reads tiny
/// on paper; the page sets its own sizes, here and only here.
private enum PrintType {
  static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
    let font = Font.system(size: size, weight: .light, design: .serif)
    return italic ? font.italic() : font
  }

  static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }
}

/// A4 in points.
enum PassportPaper {
  static let size = CGSize(width: 595, height: 842)
}

// MARK: - Page 1: cover

struct PassportDocumentCover: View {
  let sample: PassportSample

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.moonCream, Color.softLilac.opacity(0.35), GardenColor.meadow.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [Color.blushPowder.opacity(0.45), .clear],
        center: .init(x: 0.5, y: 0.12),
        startRadius: 0,
        endRadius: 260
      )

      VStack(spacing: 0) {
        Text("deep")
          .font(PrintType.serif(44, italic: true))
          .foregroundStyle(.irisDusk)
          .padding(.top, 64)
        Text("GROWTH PASSPORT")
          .font(PrintType.sans(13, .medium))
          .tracking(5)
          .foregroundStyle(.deepPlum)
          .padding(.top, 10)
        Text("A record of practice, growth and kindness")
          .font(PrintType.serif(15, italic: true))
          .foregroundStyle(.driftGrey)
          .padding(.top, 12)

        Spacer(minLength: 0)

        // Multiply doesn't survive ImageRenderer here, so the art's white
        // square is feathered away instead, leaving a soft halo behind the tree.
        PassportArt.oak(stage: sample.currentStageIndex)
          .resizable()
          .scaledToFit()
          .frame(width: 320, height: 320)
          .mask {
            RadialGradient(
              colors: [.black, .black, .clear],
              center: .center,
              startRadius: 0,
              endRadius: 160
            )
          }

        Text(sample.currentStage.name)
          .font(PrintType.serif(30))
          .foregroundStyle(.deepPlum)
          .padding(.top, 8)
        Text(sample.plantTraits.joined(separator: ", "))
          .font(PrintType.sans(13))
          .foregroundStyle(.driftGrey)
          .padding(.top, 6)

        Spacer(minLength: 0)

        VStack(spacing: 6) {
          Text("THIS PASSPORT BELONGS TO")
            .font(PrintType.sans(10, .medium))
            .tracking(2.5)
            .foregroundStyle(.driftGrey)
          Text(sample.memberName)
            .font(PrintType.serif(32))
            .foregroundStyle(.deepPlum)
          Text("Growing with DEEP since \(sample.memberSince.formatted(.dateTime.month(.wide).year()))")
            .font(PrintType.sans(13))
            .foregroundStyle(.driftGrey)
        }
        .padding(.bottom, 64)
      }
      .padding(.horizontal, 56)
    }
    .frame(width: PassportPaper.size.width, height: PassportPaper.size.height)
  }
}

// MARK: - Page 2: portfolio

struct PassportDocumentPortfolio: View {
  let sample: PassportSample
  var sections = PassportSections()

  var body: some View {
    ZStack(alignment: .top) {
      Color.moonCream
      RadialGradient(
        colors: [Color.softLilac.opacity(0.35), .clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 420
      )

      VStack(alignment: .leading, spacing: 15) {
        header
        if sections.garden { garden }
        if sections.practice { practice }
        if sections.compassion, !sample.gifts.isEmpty { compassion }
        if sections.challenges, !sample.challenges.isEmpty { challenges }
        if sections.note { note }
        Spacer(minLength: 0)
        footer
      }
      .padding(.horizontal, 44)
      .padding(.vertical, 32)
    }
    .frame(width: PassportPaper.size.width, height: PassportPaper.size.height)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("deep")
          .font(PrintType.serif(22, italic: true))
          .foregroundStyle(.irisDusk)
        Text("GROWTH PASSPORT")
          .font(PrintType.sans(8, .medium))
          .tracking(2.5)
          .foregroundStyle(.driftGrey)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(sample.memberName)
          .font(PrintType.serif(18))
          .foregroundStyle(.deepPlum)
        Text("Since \(sample.memberSince.formatted(.dateTime.month(.wide).year()))")
          .font(PrintType.sans(9))
          .foregroundStyle(.driftGrey)
      }
    }
  }

  private func eyebrow(_ title: String, symbol: String, tint: Color) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(PrintType.sans(9, .semibold))
        .foregroundStyle(tint)
      Text(title)
        .font(PrintType.sans(9, .semibold))
        .tracking(1.8)
        .foregroundStyle(.deepPlum)
    }
  }

  private var garden: some View {
    VStack(alignment: .leading, spacing: 10) {
      eyebrow("MIND GARDEN", symbol: "leaf.fill", tint: GardenColor.fern)
      HStack(alignment: .top, spacing: 14) {
        ForEach(sample.stages) { stage in
          VStack(spacing: 6) {
            PassportStagePortrait(stageIndex: stage.index, diameter: 54)
              .opacity(stage.isReached ? 1 : 0.32)
              .grayscale(stage.isReached ? 0 : 0.8)
            Text(stage.name)
              .font(PrintType.serif(13))
              .foregroundStyle(.deepPlum)
            Text(stage.reachedOn?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "Still growing")
              .font(PrintType.sans(9))
              .foregroundStyle(.driftGrey)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.vertical, 10)
      .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private var practice: some View {
    VStack(alignment: .leading, spacing: 10) {
      eyebrow("PRACTICE", symbol: "wind", tint: .lavenderMist)
      HStack(spacing: 10) {
        figure(sample.sessions, "DEEP Sessions")
        figure(sample.minutes, "minutes")
        figure(sample.practiceDays, "days practised")
        figure(sample.pausesAttended, "Global Pauses")
      }
    }
  }

  private func figure(_ value: Int, _ label: String) -> some View {
    VStack(spacing: 2) {
      Text(value.formatted())
        .font(PrintType.serif(22))
        .foregroundStyle(.deepPlum)
      Text(label)
        .font(PrintType.sans(9))
        .foregroundStyle(.driftGrey)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var compassion: some View {
    VStack(alignment: .leading, spacing: 10) {
      eyebrow("COMPASSION PORTFOLIO", symbol: "heart.fill", tint: .blushPowder)
      HStack(alignment: .center, spacing: 18) {
        ZStack {
          CompassionRing(segments: sample.giftSegments, lineWidth: 8)
          VStack(spacing: 0) {
            Text(sample.heartsGiven.formatted())
              .font(PrintType.serif(22))
              .foregroundStyle(.deepPlum)
            Text("hearts sent")
              .font(PrintType.sans(8))
              .foregroundStyle(.driftGrey)
          }
        }
        .frame(width: 96, height: 96)

        VStack(alignment: .leading, spacing: 5) {
          ForEach(sample.gifts) { gift in
            HStack(spacing: 6) {
              Circle()
                .fill(LinearGradient(colors: gift.category.palette.colors, startPoint: .top, endPoint: .bottom))
                .frame(width: 8, height: 8)
              Text(gift.category.name)
                .font(PrintType.sans(10, .medium))
                .foregroundStyle(.deepPlum)
              Text("with \(gift.category.partner.name)")
                .font(PrintType.sans(9))
                .foregroundStyle(.driftGrey)
              Spacer(minLength: 4)
              Text("\(gift.hearts)")
                .font(PrintType.sans(10, .semibold))
                .foregroundStyle(.deepPlum)
                .monospacedDigit()
            }
          }
        }
      }
      .padding(14)
      .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private var challenges: some View {
    VStack(alignment: .leading, spacing: 10) {
      eyebrow("CHALLENGES & EVENTS", symbol: "sparkles", tint: GardenColor.sunbeam)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
        ForEach(sample.challenges) { challenge in
          HStack(spacing: 8) {
            Image(systemName: challenge.symbol)
              .font(PrintType.sans(11))
              .foregroundStyle(GardenColor.sunbeam)
              .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
              Text(challenge.title)
                .font(PrintType.sans(10, .medium))
                .foregroundStyle(.deepPlum)
              Text(challenge.completedOn.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(PrintType.sans(8))
                .foregroundStyle(.driftGrey)
            }
            Spacer(minLength: 0)
          }
          .padding(9)
          .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
  }

  private var note: some View {
    VStack(alignment: .leading, spacing: 8) {
      eyebrow("A NOTE TO YOU", symbol: "envelope.fill", tint: .irisDusk)
      Text(sample.note)
        .font(PrintType.serif(13, italic: true))
        .foregroundStyle(.deepPlum)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
      Text("Strengths: \(sample.strengths.joined(separator: ", "))")
        .font(PrintType.sans(9))
        .foregroundStyle(.driftGrey)
    }
  }

  private var footer: some View {
    HStack(alignment: .center, spacing: 12) {
      PassportQRCode(text: "https://deep.app/verify/\(sample.verificationCode)")
        .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 2) {
        Text("Issued by DEEP on \(sample.issuedOn.formatted(.dateTime.day().month(.wide).year()))")
          .font(PrintType.sans(9, .medium))
          .foregroundStyle(.deepPlum)
        Text("Verify this passport at deep.app/verify/\(sample.verificationCode)")
          .font(PrintType.sans(8))
          .foregroundStyle(.driftGrey)
        Text("Figures are drawn from the member's own practice in the DEEP app.")
          .font(PrintType.sans(8))
          .foregroundStyle(.driftGrey)
      }
      Spacer()
    }
  }
}

/// A crisp QR code for the verification link.
struct PassportQRCode: View {
  let text: String

  var body: some View {
    Image(uiImage: Self.image(for: text))
      .interpolation(.none)
      .resizable()
      .scaledToFit()
  }

  private static func image(for text: String) -> UIImage {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage,
          let cg = CIContext().createCGImage(output, from: output.extent) else { return UIImage() }
    return UIImage(cgImage: cg)
  }
}

// MARK: - Rendering

enum PassportPDF {
  /// Renders the two pages into a PDF in the temp folder and returns its URL.
  @MainActor
  static func render(_ sample: PassportSample, sections: PassportSections = PassportSections()) -> URL? {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "DEEP Growth Passport \(sample.memberName).pdf")
    var box = CGRect(origin: .zero, size: PassportPaper.size)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }

    let pages: [AnyView] = [
      AnyView(PassportDocumentCover(sample: sample)),
      AnyView(PassportDocumentPortfolio(sample: sample, sections: sections)),
    ]
    // ImageRenderer's vector PDF path draws these pages' gradients, masks and
    // images as black or flat discs, so each page goes in as a 3x bitmap
    // (about 216 dpi on A4) instead.
    for page in pages {
      let renderer = ImageRenderer(content: page.environment(\.colorScheme, .light))
      renderer.scale = 3
      guard let image = renderer.cgImage else { continue }
      context.beginPDFPage(nil)
      context.draw(image, in: box)
      context.endPDFPage()
    }
    context.closePDF()
    return url
  }
}

// MARK: - Sheet

/// Previews the printable passport and hands the PDF to the share sheet
/// (Print, Save to Files, AirDrop, Mail all live there).
struct PassportExportSheet: View {
  let sample: PassportSample
  var sections = PassportSections()

  @State private var pdfURL: URL?
  @State private var page = 0

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 6) {
        Text("YOUR GROWTH PASSPORT")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Ready to print or share")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
      }
      .padding(.top, 28)

      GeometryReader { proxy in
        let scale = min(proxy.size.width / PassportPaper.size.width, proxy.size.height / PassportPaper.size.height) * 0.92
        TabView(selection: $page) {
          ForEach(0..<2, id: \.self) { index in
            Group {
              if index == 0 {
                PassportDocumentCover(sample: sample)
              } else {
                PassportDocumentPortfolio(sample: sample, sections: sections)
              }
            }
            .scaleEffect(scale)
            .frame(width: PassportPaper.size.width * scale, height: PassportPaper.size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .lavenderMist.opacity(0.35), radius: 18, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
      }

      Group {
        if let pdfURL {
          ShareLink(item: pdfURL) {
            Label("Export PDF", systemImage: "square.and.arrow.up")
              .font(DeepType.body.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(minHeight: 56)
              .background {
                Capsule().fill(
                  LinearGradient(colors: [.lavenderMist, .softLilac], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
              }
              .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
          }
          .buttonStyle(.softPress)
          .accessibilityIdentifier("prototype.exportPDF")
        } else {
          ProgressView().frame(minHeight: 56)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, 12)
    }
    .background { AtmosphereBackground() }
    .presentationDragIndicator(.visible)
    .task { pdfURL = PassportPDF.render(sample, sections: sections) }
  }
}

#Preview("Export sheet") {
  PassportExportSheet(sample: .twoYears)
}

#Preview("Cover page") {
  PassportDocumentCover(sample: .sixMonths)
}

#Preview("Portfolio page — two years") {
  PassportDocumentPortfolio(sample: .twoYears)
}
#endif
