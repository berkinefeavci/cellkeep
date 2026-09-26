import Foundation

@main enum NativeChargeHelperTests {
    static func main() throws {
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            guard value() else { fatalError(label) }
            count += 1
        }

        check(NativeChargeHelperCommand.parse(["read"]) == .read, "read accepted")
        check(NativeChargeHelperCommand.parse(["set", "80"]) == .set(80), "80 accepted")
        check(NativeChargeHelperCommand.parse(["set", "100"]) == .set(100), "100 accepted")
        check(NativeChargeHelperCommand.parse(["set", "79"]) == nil, "79 rejected")
        check(NativeChargeHelperCommand.parse(["set", "85", "extra"]) == nil, "extra argument rejected")
        check(NativeChargeHelperCommand.parse(["/tmp/file"]) == nil, "path rejected")

        let encoded = try NativeChargeHelperOutput.success([
            "manualLimit": 85,
            "availableLimits": [80, 85, 90, 95, 100],
            "enabledRaw": 1,
            "currentLimit": 85
        ])
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        check(object?["schemaVersion"] as? Int == 1, "schema encoded")
        check(object?["ok"] as? Bool == true, "success encoded")
        check((object?["state"] as? [String: Any])?["manualLimit"] as? Int == 85, "state encoded")

        let failure = try NativeChargeHelperOutput.failure("reddedildi")
        let failureObject = try JSONSerialization.jsonObject(with: failure) as? [String: Any]
        check(failureObject?["ok"] as? Bool == false, "failure flag encoded")
        check(failureObject?["error"] as? String == "reddedildi", "failure message encoded")

        print("Native charge helper: \(count) assertions passed; parser/JSON only.")
    }
}
