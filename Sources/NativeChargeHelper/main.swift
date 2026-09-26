import Foundation
#if !NATIVE_CHARGE_HELPER_TESTING
import PowerUIBridge
#endif

#if !NATIVE_CHARGE_HELPER_TESTING
private func emit(_ data: Data, status: Int32) -> Never {
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0a]))
    exit(status)
}

private func selfTest() -> Bool {
    guard NativeChargeHelperCommand.parse(["read"]) == .read,
          NativeChargeHelperCommand.parse(["set", "85"]) == .set(85),
          NativeChargeHelperCommand.parse(["set", "79"]) == nil,
          let data = try? NativeChargeHelperOutput.failure("test"),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
    return object["schemaVersion"] as? Int == 1 && object["ok"] as? Bool == false
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] {
    if selfTest() {
        print("Native charge helper: parser/JSON self-test passed; no hardware access.")
        exit(0)
    }
    exit(1)
}

guard let command = NativeChargeHelperCommand.parse(arguments) else {
    emit((try? NativeChargeHelperOutput.failure("Geçersiz yardımcı komutu.")) ?? Data(), status: 2)
}
let raw: [String: Any]
switch command {
case .read:
    raw = CMPowerLimit.readState()
case .set(let limit):
    raw = CMPowerLimit.apply(UInt8(limit))
}
if let error = raw["error"] as? String {
    emit((try? NativeChargeHelperOutput.failure(error)) ?? Data(), status: 1)
}
do { emit(try NativeChargeHelperOutput.success(raw), status: 0) }
catch { emit((try? NativeChargeHelperOutput.failure("Yanıt kodlanamadı.")) ?? Data(), status: 1) }
#endif
