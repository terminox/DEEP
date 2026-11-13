# DEEP on the App Store: listing kit

Everything App Store Connect asks for, ready before the client's account is set up. The text is in `metadata/`, laid out the way `fastlane deliver` and the App Store Connect API expect it.

| What | File | Where it goes in App Store Connect |
|---|---|---|
| Name, subtitle, promotional text, description, keywords, URLs (en-US, th) | `metadata/<locale>/*.txt` | The version's localizations; App Information |
| Copyright, categories | `metadata/*.txt` | The version; App Information |
| Screenshots, iPhone (en-US, th) | the existing iPhone set from `store-screenshots/` | The version ▸ iPhone screenshots |
| Paywall screenshots | `screenshots/paywall/<locale>.png` | Each subscription ▸ Review Information |
| Review notes, demo account | `review-notes.md` | The version ▸ App Review Information |
| Privacy label | `app-privacy.md` | App Privacy |
| Age rating | `age-rating.md` | App Information ▸ Age Rating |
| Subscriptions | `subscriptions.md` | Monetization ▸ Subscriptions |

The English and Thai descriptions start from the client-approved Google Play listing, word for word. Apple requires a DEEP Premium section with the subscription terms and a Terms of Service link, so that's added at the end.

## App information

- **Bundle ID:** `space.deeppeace.app`. SKU: `deep-ios`
- **Primary language:** English (U.S.), with Thai added as a localization
- **Category:** Health & Fitness, with Lifestyle as secondary
- **Price:** Free, with in-app subscriptions
- **Availability:** all territories, unless the client wants to start with Thailand
- **Content rights:** DEEP contains no third-party content it lacks the rights to. Some plant art is AI-made, and that was disclosed on Google Play.

## Before Submit for Review

These are not code. Each one is a reason App Review would reject the submission or the client would object.

- [ ] **Store name is free.** "DEEP" alone is probably taken. If App Store Connect refuses it, decide a fallback with the client (≤30 characters, e.g. "DEEP: Pause with the World").
- [ ] **Legal pages final.** `deeppeace.space/terms` and `/privacy` still show "Draft for review" and the `[Client legal name]`, `[Client registered address]` and `[N]` placeholders (`deep-web/src/legal/document.ts`). Fill them in, set `isDraft: false`, and redeploy.
- [ ] **Copyright holder:** replace `[Client legal name]` in `metadata/copyright.txt`.
- [ ] **Exclusive plants exist.** The paywall and the description both promise "exclusive plants for your Mind Garden", but production has **no** premium plant today (all four are free). Mark at least one finished plant as premium in the admin before review, or remove that promise from the paywall and the description.
- [ ] **Review contact:** the client's name, phone and email in App Review Information.
- [ ] **Paid Applications agreement** active (Business ▸ Agreements), or the subscriptions won't load for the reviewer.
- [ ] **Both subscriptions attached to the version** (see `subscriptions.md`).
- [ ] **Production backend** carries Report/Block and the RevenueCat webhook (PR #80 and the deploy that follows it).
- [ ] **RevenueCat** has the In-App Purchase key, or a sandbox purchase never unlocks anything (issue #53).
