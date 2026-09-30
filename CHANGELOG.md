# Changelog

## 1.1.3

- Menu bar panel: the locked Discharge action is a small icon, so "Limit" and "Top Up" keep their full labels in every language.
- Charge Control: the status header ("Holding the limit: 80%", "Top Up: 73% → 100%") is translated instead of staying in Turkish.
- Settings sidebar: the status badge reads "Verified" on one line instead of a cut-off "macOS limit · ver…".
- Dashboard: the cycle-count card no longer shows the raw temperature sensor id; it moved to the card's tooltip.

## 1.1.2

- English, German, French and Spanish: percentages read "62%" (or "62 %") instead of the Turkish "%62", chart ranges and durations use h/min, and the "Automations" sidebar heading is translated.

## 1.1.1

- Menu bar panel: toolbar labels stay on one line instead of wrapping mid-word; the limit reads "Sınır: %80" in Turkish, and the French and Spanish Top Up labels are shorter.
- Homebrew: upgrades keep Cellkeep's helpers; `brew uninstall --zap --cask cellkeep` removes them.

## 1.1.0

- Languages: English, German, French and Spanish, plus a language picker in Settings → General.
- Optional system-wide shortcut (⌃⌥⌘B or ⌃⌥⌘C) that opens and closes the menu bar panel.
- Long-term battery health trend, charging statistics, and CSV export of history and daily summaries.
- Detects other charge-limit tools (AlDente, Battery Toolkit, BatFi, batt, battery, bclm), not just AlDente; the MagSafe LED helper also steps aside while AlDente, Battery Toolkit, BatFi or batt is running. Existing LED helpers ask to be reinstalled once.
- Optional, off-by-default check for a newer release.
- Homebrew: `brew install --cask berkinefeavci/cellkeep/cellkeep`.

## 1.0.0 — first public release

First public release, under the name Cellkeep (previously developed internally as "ChargeMate").

- Native charge limit (80–100%, 5% steps) through macOS's own charge-control mechanism, with an independent read-back check on apply.
- Top Up: temporary charge to 100%, with automatic restore of your usual limit.
- Live power-flow diagram: adapter, battery, measured CPU/display watts, and "other," plus read-only connected-device wattage when unambiguous.
- History charts (1 h / 6 h / 24 h) for charge level, power draw, and battery health (hourly-smoothed max-capacity chart).
- Power modes (Automatic / High Power / Low Power) tracked separately per power source (battery vs. adapter).
- Optional idle-sleep prevention while charging below target, with an 8-hour safety cutoff.
- Manual and scheduled MagSafe LED control via a signed, narrowly scoped privileged helper.
- Schedules with a filterable execution history.
- Eight Apple Shortcuts actions (read battery/status, apply limit, Top Up, power mode, MagSafe LED).
- High-energy-app list with per-app Quit.
- Customizable panel with square and wide widgets.
- Discharge, Sailing, heat protection, and Calibration are visible in the UI as locked — they are not implemented; see the README for why.

## Pre-1.0 history

Built and iterated on internally over several weeks (previously named "ChargeMate") through roughly 60 incremental builds: starting from a basic native charge-limit reader, then adding live power-flow measurement, history charts, connected-device detection, power-mode-per-source switching, sleep behavior, MagSafe LED control, scheduling, Apple Shortcuts support, a customizable panel, and substantial UI refinement. Locked/unverified features (Discharge, Sailing, Heat protection, Calibration) were investigated and explicitly gated off rather than shipped as fake controls.
