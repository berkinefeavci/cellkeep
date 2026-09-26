# Privacy

Cellkeep is a local-only macOS app. Short version: nothing leaves your Mac.

- **No network access.** Cellkeep makes no network requests — no update checks, no telemetry, no crash reporting, no ads.
- **No analytics, no accounts.** There is no sign-in, no user identifier, no usage tracking of any kind.
- **No data collection by the developer.** The developer never receives any information from your installation.
- **Local storage only.** Preferences, charge history, and schedules are stored in standard macOS locations (`UserDefaults`, local application-support files) on your Mac only.
- **Diagnostics are opt-in and local.** The in-app "export diagnostics" feature writes a plain-text report to a file you choose, via a standard macOS save panel. It is never uploaded anywhere automatically; you decide who sees it.
- **No serial numbers or personal identifiers are read or stored.** Where Cellkeep reads hardware/device metadata (e.g. a connected iPhone's class over USB), it deliberately avoids reading or recording per-device serial numbers.

If this ever changes, it will be called out here and in the changelog before it ships.
