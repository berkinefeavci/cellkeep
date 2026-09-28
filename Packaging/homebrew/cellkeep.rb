cask "cellkeep" do
  version "1.0.0"
  sha256 "af3299948cc4d61b41d783a93e435d3a5a02079359f65f6a430187314ec580e4"

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
