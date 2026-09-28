# Homebrew cask

`cellkeep.rb` installs the signed, notarized release DMG from GitHub Releases.

## One-time setup (maintainer)

Homebrew installs third-party casks from a "tap", a public repository named `homebrew-<name>`:

1. Create the public repository `berkinefeavci/homebrew-cellkeep`.
2. Copy `cellkeep.rb` into it as `Casks/cellkeep.rb` and push.

Users then install and update with:

```sh
brew install --cask berkinefeavci/cellkeep/cellkeep
brew upgrade --cask cellkeep
```

## Each release

1. Build and upload the release as usual (`./release.sh`, then attach `Cellkeep-<version>.dmg`).
2. Update the cask with the exact DMG you uploaded:
   ```sh
   Tools/update-cask.sh <version> path/to/Cellkeep-<version>.dmg
   ```
3. Copy the updated `cellkeep.rb` to the tap's `Casks/cellkeep.rb` and push.
4. Optionally check it: `brew audit --cask --strict berkinefeavci/cellkeep/cellkeep` and
   `brew install --cask berkinefeavci/cellkeep/cellkeep` on a clean Mac.

`brew upgrade` runs the old version's `uninstall` step, so that step only quits the app; the root
helpers and their launch daemons stay installed across upgrades. `brew uninstall --zap --cask cellkeep`
also removes the helpers, launch daemons, data and preferences, as does Settings → General →
Uninstall Cellkeep. The macOS charge limit itself is a system setting and is left as it was.
