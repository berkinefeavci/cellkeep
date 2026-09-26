# Cellkeep

🇹🇷 [Türkçe README](README.tr.md)

A macOS menu-bar app that helps you look after your MacBook's battery: a native charge limit, live power-flow readout, and history — without a background daemon watching everything.

> Cellkeep was previously developed under the name "ChargeMate." Some file paths, labels, and screenshots below are still transitioning to the new name.

## Screenshots

<p align="center"><img src="docs/screenshots/menu-bar-panel.png" alt="Cellkeep menu bar panel: charge bar, power modes and live power flow" width="420"></p>

## Features

- **Charge limit, 80–100%.** Cellkeep drives macOS's own native charge-limit control (the same mechanism macOS itself uses) to hold your battery at a target between 80% and 100% in 5% steps. Applying a limit is a real read/write round trip with an independent read-back check — see [Limitations](#how-it-works-and-limitations) for what that does and does not prove.
- **Top Up.** Temporarily charge to 100% for a trip, then Cellkeep restores your usual limit afterward.
- **Live power flow.** A diagram of adapter, battery, CPU, display, and "other" power, in watts. CPU and display watts are read from Apple's SMC sensors; the total system draw comes from the battery controller. Nothing here is estimated or invented — if a value can't be measured, it shows as "—" instead of a guess.
- **Connected device power.** When exactly one USB device is drawing power on exactly one active port, Cellkeep shows its wattage (read-only, from the battery controller's port telemetry). With more than one device or port, it shows "—" rather than a guess.
- **History charts.** 1 hour / 6 hour / 24 hour views of charge level, power draw, and battery health.
- **Battery health.** A maximum-capacity chart, smoothed to hourly medians so day-to-day sensor noise doesn't look like a real health swing.
- **Power modes per source.** Automatic / High Power (Turbo) / Low Power (Battery Saver), tracked separately for "on battery" and "on adapter," backed by macOS's own `pmset` power profiles through a narrowly scoped, allowlisted helper.
- **Sleep behavior.** Optional: while charging below your target with the adapter connected, Cellkeep holds a public macOS idle-sleep assertion so your Mac keeps charging instead of going to sleep. It has an 8-hour safety cutoff and never touches lid-close or screen sleep. It does not pause charging by itself during sleep — see Limitations.
- **MagSafe LED control.** Manual System / Green / Orange / Off control, plus an always-off or scheduled-hours policy, via a signed, narrowly scoped privileged helper that only writes one known SMC key.
- **Schedules.** Recurring or one-off actions (apply a limit, switch power mode, and more) with a filterable execution history.
- **Apple Shortcuts actions.** Eight App Intents to read battery percentage, temperature, and status, and to apply a limit, start/cancel Top Up, switch power mode, or set the MagSafe LED.
- **High-energy apps, with Quit.** The energy list groups helper processes under their owning app, shows a real icon, and lets you quit an app straight from the list.
- **Customizable panel.** Drag to reorder, add or remove cards, and pick square or wide widgets.

### Planned; needs hardware verification

These are visible in the UI as locked/disabled, or not present at all. They are **not working features** — do not expect them to do anything yet:

- **Discharge / auto-discharge** — no verified way to force the battery to discharge on this hardware.
- **Sailing** (oscillate within a range) — needs a working pause/resume primitive that hasn't been found.
- **Heat protection** — needs the same pause/resume primitive plus fresh temperature data.
- **Calibration** — a long-running, restorable discharge/recharge cycle; not implemented.

## Requirements

- **Apple Silicon (arm64) only.**
- Tested on **macOS 27**, on a single Mac model. Other macOS versions and other Mac models are **untested** — they may work, may not build, or may silently misbehave. Please file an issue with your Mac model and macOS version if you try one.

## Install

1. Download the latest `.dmg` from [Releases](../../releases).
2. Open it and drag Cellkeep to Applications.
3. On first launch, macOS may warn that the app is from an unidentified developer if it isn't notarized yet — open System Settings → Privacy & Security and allow it.
4. The first time you use a feature that needs a privileged helper (power-mode switching or MagSafe LED control), macOS will ask for administrator approval once for that helper. No password is stored by Cellkeep.

## Build from source

Requires Xcode 27.

```sh
cd project
./check.sh
./build.sh
```

`check.sh` runs the pure-logic test suite. `build.sh` produces `project/.build/ChargeMate.app`.

## Uninstall

In-app (recommended): Settings → General → **"Cellkeep'i kaldır"** (Remove Cellkeep). After one administrator prompt it removes the helpers and launch daemons, unregisters the login item, can reset the macOS charge limit to 100% (on by default) and can delete Cellkeep's data (off by default). Then drag `Cellkeep.app` to the Trash.

Manual alternative:


1. Quit Cellkeep and turn off "Start at login" in Settings first.
2. Move `Cellkeep.app` from `/Applications` to the Trash.
3. Remove the privileged helpers, if installed:
   ```sh
   sudo launchctl bootout system/io.github.berkinefeavci.cellkeep.powermode 2>/dev/null
   sudo launchctl bootout system/io.github.berkinefeavci.cellkeep.led 2>/dev/null
   sudo rm -f /Library/LaunchDaemons/io.github.berkinefeavci.cellkeep.powermode.plist
   sudo rm -f /Library/LaunchDaemons/io.github.berkinefeavci.cellkeep.led.plist
   sudo rm -f /Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.powermode
   sudo rm -f /Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.led
   ```
4. If you uninstall manually, your macOS charge limit stays as it was: it is a macOS setting. Change it in System Settings → Battery if you want to.

## How it works, and limitations

Cellkeep reads and writes through Apple's private `PowerUI` framework (the same subsystem macOS's own Battery settings use) and reads a small number of documented, read-only SMC keys. This is not a public, stable API: **a macOS update can break it without warning**, and Cellkeep has no way to detect that in advance.

The most important limitation: **applying a charge limit is a verified configuration write with an independent read-back — it is not proof that physical charge current actually stops at that percentage.** Cellkeep has confirmed that macOS accepts and reports back the requested limit; it has not run a controlled physical experiment (battery held above the target, charger connected, competing controllers closed) to confirm the current is actually cut. Treat the limit as "macOS says it's set," not as a guarantee.

Everywhere else, the same rule applies: if a number can't be measured, Cellkeep shows "—" instead of inventing one. No measurement is fabricated or interpolated for display.

## Privacy

Cellkeep runs entirely on your Mac. There is no network access, no telemetry, no analytics, and no account. Diagnostics you export are saved to a local file you choose and are never sent anywhere automatically.

See [PRIVACY.md](PRIVACY.md).

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for build/test commands and the rules around hardware-writing code.

If Cellkeep is useful to you: <!-- TODO: Buy Me a Coffee link --> ☕

## Security

Found a vulnerability? Please see [SECURITY.md](SECURITY.md) — do not open a public issue.

## License

MIT — see [LICENSE](LICENSE).
