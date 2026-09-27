# Contributing

Thanks for considering a contribution to Cellkeep.

## Build and test

Requires Xcode 27, Apple Silicon Mac.

```sh
./check.sh   # pure-logic test suite, no hardware writes
./build.sh   # produces .build/Cellkeep.app
```

Read `check.sh` and `build.sh` before running them — they're plain shell scripts, not a black box.

## Rules

- **No hardware-writing tests in CI.** Anything that would write to the battery controller, SMC, `pmset`, or a privileged helper must be a pure-logic or fake-backend test that runs offline. Real hardware writes are only ever exercised manually, locally, by someone with the physical Mac in front of them.
- **No fabricated measurements.** If a value can't be read, the code shows "—" or an explicit "unavailable" state — never an estimate, interpolation, or placeholder presented as a real reading. This applies to UI, tests, and PR descriptions alike: don't claim a measurement or hardware behavior you haven't actually observed.
- Keep changes scoped and explain in the PR description what you tested and how (including what you could *not* test, e.g. "no physical MagSafe cable available").
- Match existing code style; there's no separate linter config to satisfy beyond `check.sh` passing.
