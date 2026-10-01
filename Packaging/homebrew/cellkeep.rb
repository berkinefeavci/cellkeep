cask "cellkeep" do
  version "1.1.6"
  sha256 "093e38972e90262146e6a49055d200e3db763c2131d1b2f47609bd40c5592d90"

  url "https://github.com/berkinefeavci/cellkeep/releases/download/v#{version}/Cellkeep-#{version}.dmg"
  name "Cellkeep"
  desc "Menu bar charge limiter and battery monitor"
  homepage "https://github.com/berkinefeavci/cellkeep"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Cellkeep.app"

  # `brew upgrade` runs `uninstall` too, so it only quits the app. Removing the root helpers there
  # would ask for a password on every upgrade and turn off the LED and power-mode helpers.
  uninstall quit: "io.github.berkinefeavci.cellkeep"

  zap launchctl: [
        "io.github.berkinefeavci.cellkeep.led",
        "io.github.berkinefeavci.cellkeep.powermode",
      ],
      delete:    [
        "/Library/Application Support/CellkeepLED",
        "/Library/Application Support/CellkeepPowerMode",
        "/Library/LaunchDaemons/io.github.berkinefeavci.cellkeep.led.plist",
        "/Library/LaunchDaemons/io.github.berkinefeavci.cellkeep.powermode.plist",
        "/Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.led",
        "/Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.powermode",
      ],
      trash:     [
        "~/Library/Application Support/Cellkeep",
        "~/Library/Preferences/io.github.berkinefeavci.cellkeep.plist",
      ]

  caveats <<~EOS
    Upgrades keep Cellkeep's helpers. To remove them, use Settings → General → Uninstall
    Cellkeep first, or `brew uninstall --zap --cask cellkeep`.
    Cellkeep's charge limit uses macOS's own charge-limit setting, which stays as it was
    after uninstalling. Reset it in System Settings → Battery if you want to.
  EOS
end
