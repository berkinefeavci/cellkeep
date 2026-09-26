import AppKit
import Foundation

/// Executes an `UninstallPlan` for real: one admin prompt for every helper/daemon removal (new
/// and legacy "ChargeMate" labels), then the non-privileged steps. This is the only side-effecting
/// half of uninstall — `UninstallPlan` itself stays pure and is what the unit tests cover.
enum UninstallExecutor {
    enum ExecutionError: LocalizedError {
        case adminDenied(String)
        var errorDescription: String? {
            switch self {
            case .adminDenied(let message): return message
            }
        }
    }

    static func run(options: UninstallPlan.Options, battery: BatteryMonitor) async -> Result<Void, ExecutionError> {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cellkeep").path
        let steps = UninstallPlan.build(options: options, applicationSupportDirectory: supportDirectory)

        if let command = UninstallPlan.adminShellCommand(for: steps) {
            do { try authorized(command) }
            catch let error as ExecutionError { return .failure(error) }
            catch { return .failure(.adminDenied(error.localizedDescription)) }
        }

        _ = try? StartupPreferences.setLoginItemEnabled(false)

        if steps.contains(.resetNativeChargeLimitTo100) {
            _ = await battery.applyShortcutLimit(100)
        }

        for step in steps {
            if case .removeApplicationSupportData(let path) = step {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        return .success(())
    }

    private static func authorized(_ command: String) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "macOS yönetici izni vermedi."
            throw ExecutionError.adminDenied(message)
        }
    }
}
