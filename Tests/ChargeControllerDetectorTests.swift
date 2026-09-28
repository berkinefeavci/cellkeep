import Foundation

@main enum ChargeControllerDetectorTests {
    static func main() {
        let home = "/Users/test"
        typealias S = ChargeControllerDetector.Signals
        func detect(_ s: S) -> [String] { ChargeControllerDetector.detect(s, home: home) }

        // Nothing running, nothing installed.
        precondition(detect(S()).isEmpty)
        // GUI apps by bundle identifier prefix, including helper/pro variants.
        precondition(detect(S(bundleIdentifiers: ["com.apphousekitchen.aldente-pro"])) == ["AlDente"])
        precondition(detect(S(bundleIdentifiers: ["me.mhaeuser.BatteryToolkitAutostart"])) == ["Battery Toolkit"])
        precondition(detect(S(bundleIdentifiers: ["software.micropixels.BatFi"])) == ["BatFi"])
        precondition(detect(S(bundleIdentifiers: ["co.palokaj.battery"])) == ["battery"])
        // Background daemons by process name; long names arrive truncated to 32 characters.
        precondition(detect(S(processNames: ["me.mhaeuser.batterytoolkitd"])) == ["Battery Toolkit"])
        precondition(detect(S(processNames: ["software.micropixels.BatFi.Helpe"])) == ["BatFi"])
        precondition(detect(S(processNames: ["batt"])) == ["batt"])
        // Short names match exactly only: no false positive on look-alikes.
        precondition(detect(S(processNames: ["battery", "batteryd", "battd", "combatt"])).isEmpty)
        // Boot/login-time jobs that re-apply their own limit.
        precondition(detect(S(existingPaths: ["/Library/LaunchDaemons/com.zackelia.bclm.plist"])) == ["bclm"])
        precondition(detect(S(existingPaths: [home + "/Library/LaunchAgents/battery.plist"])) == ["battery"])
        precondition(detect(S(existingPaths: ["/Users/other/Library/LaunchAgents/battery.plist"])).isEmpty)
        // Unrelated apps and Cellkeep itself are never a rival.
        precondition(detect(S(bundleIdentifiers: ["io.github.berkinefeavci.cellkeep", "com.apple.Safari"],
                              processNames: ["Cellkeep", "kernel_task"])).isEmpty)
        // Several at once: known order, no duplicates.
        precondition(detect(S(bundleIdentifiers: ["software.micropixels.BatFi", "com.apphousekitchen.aldente"],
                              processNames: ["software.micropixels.BatFi.Helpe"])) == ["AlDente", "BatFi"])
        // Only GUI apps are offered for a graceful quit.
        precondition(ChargeControllerDetector.quittableBundlePrefixes(home: home).contains("com.apphousekitchen.aldente"))
        print("Charge controller detector: bundle, process, launchd and no-false-positive assertions passed.")
    }
}
