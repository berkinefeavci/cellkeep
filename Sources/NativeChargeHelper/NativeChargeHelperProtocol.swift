import Foundation

enum NativeChargeHelperCommand: Equatable {
    case read
    case set(Int)

    static func parse(_ arguments: [String]) -> Self? {
        if arguments == ["read"] { return .read }
        guard arguments.count == 2, arguments[0] == "set",
              let limit = Int(arguments[1]), [80, 85, 90, 95, 100].contains(limit) else { return nil }
        return .set(limit)
    }
}

enum NativeChargeHelperOutput {
    static func success(_ state: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "ok": true, "state": state],
                                   options: [.sortedKeys])
    }

    static func failure(_ message: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "ok": false, "error": message],
                                   options: [.sortedKeys])
    }
}
