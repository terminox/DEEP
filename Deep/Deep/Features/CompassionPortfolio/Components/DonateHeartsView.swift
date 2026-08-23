import SwiftUI

/// Choosing how many hearts to send to one cause. Opened from a cause card's
/// donate button; the coordinator owns the presentation, this owns the act.
///
/// The amount is entered on the app's own soft keypad rather than the system
/// number pad: grey system keys sliding up over the atmosphere is the one thing
/// on this screen that would look borrowed from another product, and DESIGN.md
/// rules out hard slides besides. Quick amounts sit above the pad so the common
/// answers need no typing at all.
struct DonateHeartsView: View {
  @Environment(\.heartLedger) private var ledger
  @Environment(\.dismiss) private var dismiss
  let category: CompassionCategory

  @State private var amount = 0
  /// Whether the next digit starts a new number rather than extending the one
  /// on screen. True after a quick amount is chosen (and for the opening
  /// suggestion), so typing over "All" writes what was typed instead of being
  /// swallowed by the ceiling.
  @State private var entryIsFresh = true
  @State private var burst = 0
  /// Set once hearts have gone, so the button can confirm before the sheet
  /// leaves. Holds what was actually given, which may be less than was asked.
  @State private var donated: Int?

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        cause
        readout
        quickAmounts
        HeartAmountPad(
          onDigit: append,
          onDelete: {
            ledger.clearSpendFailure()
            amount /= 10
            entryIsFresh = false
          },
          onClear: {
            ledger.clearSpendFailure()
            amount = 0
            entryIsFresh = true
          }
        )
        action

        // A refused spend rolled back quietly; touching the pad again — or
        // the next donate — clears the caption.
        if let failure = ledger.spendFailure, failure.categoryID == category.id {
          Text(rollbackLine(for: failure))
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.top, .rhythm)
      .padding(.bottom, .rhythm)
      // Once the hearts are gone the sheet is only finishing its sentence.
      .allowsHitTesting(donated == nil)
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollIndicators(.hidden)
    .animation(.settle, value: ledger.spendFailure)
    .sensoryFeedback(.selection, trigger: amount)
    .presentationDetents([.height(560), .large])
    .presentationBackground { AtmosphereBackground() }
    .onAppear { amount = Swift.min(10, ledger.balance) }
  }

  // MARK: - Cause

  private var cause: some View {
    HStack(spacing: 14) {
      CompassionMotif(symbol: category.symbol, palette: category.palette, cornerRadius: 14)
        .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 2) {
        Text(category.name)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
        Text(category.tagline)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
      }
      // A `Spacer` here would bid against the text column and wrap the name on
      // a row with room to spare; a greedy frame leaves the text its width.
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Amount

  /// The chosen amount, on its own axis — the portfolio card's altar treatment
  /// at sheet scale, warmth gathered under the numeral by a re-centred copy of
  /// the frosted card's own tint recipe.
  private var readout: some View {
    VStack(spacing: 6) {
      HStack(spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.blushPowder)
        Text(amount.formatted())
          .font(DeepType.bigNumber)
          // An empty field, not a score of nothing: at zero the numeral reads
          // as a placeholder rather than something the member is short of.
          .foregroundStyle(amount > 0 ? Color.deepPlum : Color.driftGrey)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(amount)))
      }
      .background {
        RadialGradient(
          colors: [Color.blushPowder.opacity(0.32), Color.blushPowder.opacity(0)],
          center: .center,
          startRadius: 2,
          endRadius: 96
        )
        .frame(width: 196, height: 120)
        .allowsHitTesting(false)
      }

      Text("of \(ledger.balance.formatted()) hearts you hold")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Hearts to donate")
    .accessibilityValue("\(amount) of \(ledger.balance)")
  }

  /// The amounts worth one tap. The ladder steps down for a small balance, and
  /// "All" is only offered when it isn't already one of the steps.
  private var quickAmounts: some View {
    let ladder = (ledger.balance >= 10 ? [10, 50, 100] : [1, 5]).filter { $0 <= ledger.balance }
    return HStack(spacing: 8) {
      ForEach(ladder, id: \.self) { value in
        chip(label: value.formatted(), value: value)
      }
      if !ladder.contains(ledger.balance) {
        chip(label: "All", value: ledger.balance)
      }
    }
  }

  private func chip(label: String, value: Int) -> some View {
    let selected = amount == value
    return Button {
      ledger.clearSpendFailure()
      withAnimation(.exhale) { amount = value }
      entryIsFresh = true
    } label: {
      Text(label)
        .font(DeepType.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(selected ? Color.white : Color.deepPlum)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
          Capsule().fill(
            selected
              ? AnyShapeStyle(
                LinearGradient(
                  colors: [.lavenderMist, .blushPowder],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              : AnyShapeStyle(Color.white.opacity(0.38))
          )
        }
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(value == ledger.balance ? "All \(value) hearts" : "\(value) hearts")
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }

  /// Typing past what you hold stops at what you hold — the caption under the
  /// numeral already says what the ceiling is, so the number simply declines to
  /// climb rather than throwing anything away.
  private func append(_ digit: Int) {
    ledger.clearSpendFailure()
    amount = Swift.min(entryIsFresh ? digit : amount * 10 + digit, ledger.balance)
    entryIsFresh = false
  }

  private func rollbackLine(for failure: HeartLedger.SpendFailure) -> String {
    failure.amount == 1
      ? "That heart couldn't be sent — it's back in your balance."
      : "Those \(failure.amount.formatted()) hearts couldn't be sent — they're back in your balance."
  }

  // MARK: - Action

  @ViewBuilder
  private var action: some View {
    Group {
      if let donated {
        capsuleLabel {
          Image(systemName: "heart.fill")
            .font(.system(size: 16, weight: .semibold))
          Text("Donated \(donated.formatted()) \(donated == 1 ? "heart" : "hearts")")
        }
        .accessibilityAddTraits(.isStaticText)
      } else if amount > 0 {
        Button(action: donate) {
          capsuleLabel {
            Image(systemName: "heart.fill")
              .font(.system(size: 16, weight: .semibold))
            Text("Donate \(amount.formatted()) \(amount == 1 ? "heart" : "hearts")")
          }
        }
        .buttonStyle(.softPress)
        .accessibilityLabel("Donate \(amount) hearts to \(category.name)")
      } else {
        // Not a dimmed button: a disabled CTA reads as something broken, and
        // there is nothing broken about a member who hasn't chosen yet.
        Text("Pick an amount")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.driftGrey)
          .padding(.horizontal, 22)
          .padding(.vertical, 16)
          .frame(maxWidth: .infinity)
          .frostedCard(cornerRadius: .chip)
      }
    }
    .animation(.exhale, value: amount > 0)
    .animation(.exhale, value: donated)
    .heartBurst(trigger: burst)
  }

  private func capsuleLabel<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 10) {
      content()
    }
    .font(DeepType.sectionTitle)
    .foregroundStyle(.white)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity)
    .background {
      Capsule().fill(
        LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
      )
    }
    .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
  }

  /// Gives, then holds for a beat so the heart has time to bloom — dismissing on
  /// the same frame would cut the one moment in this feature worth feeling.
  private func donate() {
    let given = Swift.min(amount, ledger.balance)
    guard given > 0 else { return }

    ledger.send(given, to: category)
    burst += 1
    donated = given

    Task {
      try? await Task.sleep(for: .seconds(0.9))
      dismiss()
    }
  }
}

/// The soft number pad: `pebble` keys, the same inset tonal panel that groups
/// anything else inside a Deep card. The bottom-left cell is left empty rather
/// than filled with a "clear" key — holding delete does that, and a fourth verb
/// on a pad this small reads as clutter.
private struct HeartAmountPad: View {
  let onDigit: (Int) -> Void
  let onDelete: () -> Void
  let onClear: () -> Void

  private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
  private let keyHeight: CGFloat = 52

  var body: some View {
    VStack(spacing: 10) {
      ForEach(rows, id: \.self) { row in
        HStack(spacing: 10) {
          ForEach(row, id: \.self) { digit in
            digitKey(digit)
          }
        }
      }

      HStack(spacing: 10) {
        Color.clear
          .frame(maxWidth: .infinity)
          .frame(height: keyHeight)
        digitKey(0)
        PadKey(height: keyHeight) {
          onDelete()
        } label: {
          Image(systemName: "delete.left")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.driftGrey)
        }
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.5).onEnded { _ in onClear() }
        )
        .accessibilityLabel("Delete")
        .accessibilityHint("Hold to clear")
      }
    }
  }

  private func digitKey(_ digit: Int) -> some View {
    PadKey(height: keyHeight) {
      onDigit(digit)
    } label: {
      Text(digit.formatted())
        .font(DeepType.counter)
        .monospacedDigit()
        .foregroundStyle(.deepPlum)
    }
    .accessibilityLabel(digit.formatted())
  }
}

private struct PadKey<Label: View>: View {
  private let height: CGFloat
  private let action: () -> Void
  private let label: Label

  init(height: CGFloat, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
    self.height = height
    self.action = action
    self.label = label()
  }

  var body: some View {
    Button(action: action) {
      label
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .pebble(cornerRadius: .tile)
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Donate hearts") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) {
      DonateHeartsView(category: CompassionLibrary.healthcare)
    }
    .environment(\.heartLedger, .sample)
}

/// A balance below the standard ladder, where the quick amounts step down and
/// "All" carries the whole of it.
#Preview("Donate hearts — small balance") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) {
      DonateHeartsView(category: CompassionLibrary.nature)
    }
    .environment(\.heartLedger, HeartLedger(balance: 7, heartsGiven: 41))
}

#Preview("Donate hearts — send refused") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) {
      DonateHeartsView(category: CompassionLibrary.nature)
    }
    .environment(\.heartLedger, .sendRefused)
}

#Preview("Donate hearts — accessibility1") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) {
      DonateHeartsView(category: CompassionLibrary.peace)
    }
    .environment(\.heartLedger, .sample)
    .environment(\.dynamicTypeSize, .accessibility1)
}
