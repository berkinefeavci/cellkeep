cask "cellkeep" do
  version "1.1.0"
  sha256 "5c04e95418675dcbc8d9bdc16f48cb66b63a9d75177cd1148c73207d91261a92"

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

  uninstall quit:      "io.github.berkinefeavci.cellkeep",
            launchctl: [
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
            ]

  zap trash: [
    "~/Library/Application Support/Cellkeep",
    "~/Library/Preferences/io.github.berkinefeavci.cellkeep.plist",
  ]

  caveats <<~EOS
    Cellkeep's charge limit uses macOS's own charge-limit setting, which stays as it was
    after uninstalling. Reset it in System Settings → Battery if you want to.
  EOS
end
