# App Privacy (the privacy label)

App Store Connect ▸ App Privacy. These answers match `Deep/Deep/PrivacyInfo.xcprivacy` and the Privacy Policy at https://deeppeace.space/privacy. If either one changes, change all three.

**Privacy Policy URL:** https://deeppeace.space/privacy

**Do you or your third-party partners collect data from this app?** Yes.

**Tracking:** No. DEEP doesn't link its data with other companies' data for advertising, and doesn't share it with data brokers. There's no advertising SDK and no IDFA.

| Data type | Collected | Linked to the user | Used for tracking | Purpose | Where it comes from |
|---|---|---|---|---|---|
| Contact Info ▸ **Email Address** | Yes | Yes | No | App Functionality | Sign-up and sign-in |
| Contact Info ▸ **Name** | Yes | Yes | No | App Functionality | Display name, shown on the member's peace messages |
| Identifiers ▸ **User ID** | Yes | Yes | No | App Functionality | DEEP account id, also RevenueCat's app user id |
| Purchases ▸ **Purchase History** | Yes | Yes | No | App Functionality | DEEP Premium, through RevenueCat |
| User Content ▸ **Other User Content** | Yes | Yes | No | App Functionality | Peace messages, intentions, reflections, reports |
| Usage Data ▸ **Product Interaction** | Yes | Yes | No | App Functionality | Practice sessions and listens that earn hearts and grow the plant |
| Location ▸ **Coarse Location** | Yes | **No** | No | App Functionality | Country, or an approximate area worked out from the IP address, for the live globe. It's kept under a temporary presence id, not the account. |

**Not collected:** precise location, contacts, health and fitness data, financial info, browsing or search history, diagnostics, crash data, photos, audio, sensitive info.

RevenueCat's SDK ships its own privacy manifest. Apple folds it into the report, and it agrees with the Purchases row above.
