# DEEP Premium subscriptions

These product ids are hard-coded in the app (`DeepProduct`), in `Deep.storekit`, in RevenueCat and on Google Play. **An App Store Connect product id can never be reused**, so type them exactly.

## Subscription group

| Field | Value |
|---|---|
| Reference name | DEEP Premium |
| Display name (en-US) | DEEP Premium |
| Display name (th) | DEEP Premium |
| App name shown on the receipt | DEEP |

## Products

| | Monthly | Yearly |
|---|---|---|
| Product ID | `deep.pro.monthly` | `deep.pro.yearly` |
| Reference name | DEEP Premium Monthly | DEEP Premium Yearly |
| Duration | 1 month | 1 year |
| Group level | 1 | 1 |
| Price (USD base) | $9.99 | $59.99 |
| Introductory offer | none | **Free trial, 1 week**, new subscribers, every territory |
| Family Sharing | Off | Off |
| Display name (en-US) | DEEP Premium Monthly | DEEP Premium Yearly |
| Description (en-US, ≤45) | Every sound and exclusive plants, monthly | Every sound and exclusive plants, yearly |
| Display name (th) | DEEP Premium รายเดือน | DEEP Premium รายปี |
| Description (th, ≤45) | ทุกเสียงและต้นไม้พิเศษ จ่ายรายเดือน | ทุกเสียงและต้นไม้พิเศษ จ่ายรายปี |

Prices come from `Deep/Deep/Deep.storekit`. Other territories follow Apple's equalization of the USD price unless the client sets local prices. In Thailand that came out at **฿399 / month** and **฿1,990 / year**; the client can change either in App Store Connect.

The onboarding paywall only says "free for seven days" when a 7-day trial is on offer. If the trial length changes, change that line too.

## Review information (per product)

- **Screenshot:** `screenshots/paywall/en-US.png`, the paywall showing both plans.
- **Review notes:**
  ```
  Unlocks every sound in the library and exclusive plants for the Mind Garden.
  To reach it: You → Settings → Upgrade to DEEP Premium, or tap a locked sound in the Sounds tab.
  Demo account in the app's App Review Information.
  ```

Both products must be submitted **with the first app version**. Add them under the version's "In-App Purchases and Subscriptions" section before pressing Submit for Review.

## After the products exist

- RevenueCat already lists both ids under the DEEP iOS app (`app7a402d1e0e`), attached to the `deep_premium` entitlement and the `default` offering.
- RevenueCat still needs the **In-App Purchase key** and an **App Store Connect API key** before it can validate purchases and sync these products. See issue #53.
