# Privacy

Cellkeep is a local-only macOS app. Short version: nothing about you or your Mac leaves it.

- **No network access by default.** Cellkeep makes no network requests out of the box — no telemetry, no crash reporting, no ads.
- **Optional release check (off by default).** If you turn on "Haftada bir yeni sürüm denetle" or press "Şimdi denetle" in Settings → About, Cellkeep sends one plain HTTPS GET to `api.github.com/repos/berkinefeavci/cellkeep/releases/latest`, at most once a week. It sends no identifier, settings, battery data or anything else; GitHub sees only what any web request shows (your IP address and a generic macOS user agent). A newer version is shown in the panel and in About. Only when you press "Update" does Cellkeep download that release's DMG and its `.sha256` from `github.com/berkinefeavci/cellkeep/releases`; it installs it only if the checksum matches, the app inside is signed with the same Developer ID Team as the running copy, Gatekeeper accepts it as notarized, and its version and bundle identifier are the expected ones. Otherwise nothing is installed and the release page link is offered instead.
- **No analytics, no accounts.** There is no sign-in, no user identifier, no usage tracking of any kind.
- **No data collection by the developer.** The developer never receives any information from your installation.
- **Local storage only.** Preferences, charge history, and schedules are stored in standard macOS locations (`UserDefaults`, local application-support files) on your Mac only.
- **Diagnostics are opt-in and local.** The in-app "export diagnostics" feature writes a plain-text report to a file you choose, via a standard macOS save panel. It is never uploaded anywhere automatically; you decide who sees it.
- **No serial numbers or personal identifiers are read or stored.** Where Cellkeep reads hardware/device metadata (e.g. a connected iPhone's class over USB), it deliberately avoids reading or recording per-device serial numbers.

If this ever changes, it will be called out here and in the changelog before it ships.
