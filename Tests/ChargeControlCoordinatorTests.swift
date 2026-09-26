import Foundation

@main enum CoordinatorTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-coordinator-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            guard value() else { fatalError(label) }
            count += 1
        }
        func path() -> URL { root.appendingPathComponent("\(UUID()).json") }
        func state(_ limit: Int, available: [Int] = [80, 85, 90, 95, 100]) -> NativeChargeState {
            .init(manualLimit: limit, availableLimits: available, enabledRaw: 1, currentLimit: limit)
        }
        func backend(version: String = "fake-v1",
                     read: @escaping () throws -> NativeChargeState,
                     write: @escaping (Int) throws -> NativeChargeState) -> NativeChargeBackend {
            NativeChargeBackend(version: version, timeout: 0.1) { arguments, _ in
                let value: NativeChargeState
                if arguments == ["read"] { value = try read() }
                else if arguments.count == 2, arguments[0] == "set", let limit = Int(arguments[1]) { value = try write(limit) }
                else { throw NativeChargeBackendError.rejected("unexpected fake command") }
                let data = try JSONEncoder().encode(TestEnvelope(schemaVersion: 1, ok: true, state: value))
                return .init(status: 0, output: data)
            }
        }

        var writes = 0
        var limit = 80
        let journal = path()
        let engine = ChargeControlCoordinator(journal: journal, backend: backend(read: { state(limit) }, write: {
            writes += 1; limit = $0; return state(limit)
        }), rival: { false })
        check(writes == 0, "startup must not write")
        check(engine.apply(ChargeControlCoordinator.Request(50, source: .manual)).status == .rejected && writes == 0,
              "unsupported must not write")
        let success = engine.apply(ChargeControlCoordinator.Request(85, source: .schedule))
        check(success.status == .configurationVerified && writes == 1, "success exactly once")
        let saved = try JSONDecoder().decode(ChargeControlCoordinator.Session.self, from: Data(contentsOf: journal))
        check(success.operationID == saved.id, "result exposes operation id")
        check(saved.schemaVersion == 2 && saved.source == .schedule, "source and schema persist")
        check(saved.backendVersion == "fake-v1", "backend version persists")
        check(saved.startedAt <= (saved.finishedAt ?? .distantPast), "finished timestamp persists")

        let restarted = ChargeControlCoordinator(journal: journal, backend: backend(read: { state(limit) }, write: { _ in
            writes += 1; return state(limit)
        }), rival: { false })
        check(!restarted.requiresRecovery && writes == 1, "successful restart must not write")

        let uncertainJournal = path()
        writes = 0
        let uncertain = ChargeControlCoordinator(journal: uncertainJournal,
            backend: backend(read: { state(80) }, write: { _ in writes += 1; throw NativeChargeBackendError.timedOut }),
            rival: { false })
        check(uncertain.apply(ChargeControlCoordinator.Request(85, source: .topUp)).status == .recoveryRequired && writes == 1,
              "writer timeout locks recovery")
        check(uncertain.apply(ChargeControlCoordinator.Request(90, source: .manual)).status == .recoveryRequired && writes == 1,
              "recovery blocks second write")

        writes = 0
        let readFailure = ChargeControlCoordinator(journal: path(),
            backend: backend(read: { throw NativeChargeBackendError.helperMissing }, write: { _ in writes += 1; return state(85) }),
            rival: { false })
        check(readFailure.apply(85).status == .rejected && writes == 0 && !readFailure.requiresRecovery,
              "read failure before writer is a zero-write rejection")

        writes = 0
        let rival = ChargeControlCoordinator(journal: path(), backend: backend(read: { state(80) }, write: { _ in
            writes += 1; return state(85)
        }), rival: { true })
        check(rival.apply(85).status == .rejected && writes == 0, "rival rejects")

        var reads = 0
        let lateRival = ChargeControlCoordinator(journal: path(), backend: backend(read: {
            reads += 1; return state(80)
        }, write: { _ in writes += 1; return state(85) }), rival: { reads >= 2 })
        check(lateRival.apply(85).status == .rejected && writes == 0 && !lateRival.requiresRecovery,
              "late rival rejects before writer")

        reads = 0
        let changed = ChargeControlCoordinator(journal: path(), backend: backend(read: {
            reads += 1; return state(reads == 1 ? 80 : 90)
        }, write: { _ in writes += 1; return state(85) }), rival: { false })
        check(changed.apply(85).status == .rejected && writes == 0, "changed baseline no write")

        writes = 0
        let mismatch = ChargeControlCoordinator(journal: path(), backend: backend(read: { state(80) }, write: { _ in
            writes += 1; return state(85)
        }), rival: { false })
        check(mismatch.apply(85).status == .recoveryRequired && writes == 1, "independent readback mismatch locks")

        let pending = path()
        let pendingSession = ChargeControlCoordinator.Session(id: UUID(), requested: 85, previous: 80,
            startedAt: Date(), status: .pending, source: .topUp, backendVersion: "fake-v1")
        try JSONEncoder().encode(pendingSession).write(to: pending)
        let crashed = ChargeControlCoordinator(journal: pending, backend: backend(read: { state(85) }, write: { _ in
            writes += 1; return state(85)
        }), rival: { false })
        check(crashed.requiresRecovery && crashed.apply(85).status == .recoveryRequired, "pending restart never replays")

        let legacy = path()
        let legacyObject: [String: Any] = [
            "id": UUID().uuidString, "requested": 85, "previous": 80,
            "date": ISO8601DateFormatter().string(from: Date()), "status": "configurationVerified",
            "source": "manualApply", "backendVersion": "PowerUI-MCL-v1"
        ]
        try JSONSerialization.data(withJSONObject: legacyObject).write(to: legacy)
        let legacyBytes = try Data(contentsOf: legacy)
        let migrated = ChargeControlCoordinator(journal: legacy, backend: backend(read: { state(85) }, write: { _ in state(85) }), rival: { false })
        check(!migrated.requiresRecovery, "legacy verified journal loads")
        let legacyAfter = try Data(contentsOf: legacy)
        check(legacyAfter == legacyBytes, "legacy load performs no write")

        let future = path()
        let futureBytes = Data(#"{"schemaVersion":99,"id":"00000000-0000-0000-0000-000000000000","requested":85,"previous":80,"startedAt":0,"status":"configurationVerified","source":"manual","backendVersion":"future"}"#.utf8)
        try futureBytes.write(to: future)
        let futureCoordinator = ChargeControlCoordinator(journal: future, backend: backend(read: { state(80) }, write: { _ in state(85) }), rival: { false })
        check(futureCoordinator.requiresRecovery && futureCoordinator.apply(85).status == .recoveryRequired,
              "future schema blocks writes")
        let futureAfter = try Data(contentsOf: future)
        check(futureAfter == futureBytes, "future schema preserved byte for byte")

        let corrupt = path()
        try Data("broken".utf8).write(to: corrupt)
        let broken = ChargeControlCoordinator(journal: corrupt, backend: backend(read: { state(80) }, write: { _ in
            writes += 1; return state(85)
        }), rival: { false })
        check(broken.apply(85).status == .recoveryRequired, "corrupt journal blocks")
        let corruptAfter = try String(contentsOf: corrupt, encoding: .utf8)
        check(corruptAfter == "broken", "corrupt journal preserved")

        let beforeRecovery = try Data(contentsOf: uncertainJournal)
        check(uncertain.reconcile(expectedLimit: 90).status == .recoveryRequired, "changed confirmation rejected")
        check(uncertain.reconcile(expectedLimit: 80).status == .reconciled && !uncertain.requiresRecovery,
              "explicit read-only recovery")
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("control-session-before-recovery-") }
        let evidencePreserved = try backups.contains { try Data(contentsOf: $0) == beforeRecovery }
        check(evidencePreserved, "recovery preserves evidence")

        writes = 0
        let cancelled = ChargeControlCoordinator.Request(85, source: .manual)
        cancelled.cancel()
        let cancellation = ChargeControlCoordinator(journal: path(), backend: backend(read: { state(80) }, write: { _ in
            writes += 1; return state(85)
        }), rival: { false })
        check(cancellation.apply(cancelled).status == .cancelled && writes == 0, "queued cancellation writer zero")
        check(cancellation.apply(80).status == .configurationVerified && writes == 0, "same value is zero-write success")

        let duringRead = ChargeControlCoordinator.Request(85, source: .manual)
        let duringJournal = path()
        let early = ChargeControlCoordinator(journal: duringJournal, backend: backend(read: {
            duringRead.cancel(); return state(80)
        }, write: { _ in writes += 1; return state(85) }), rival: { false })
        check(early.apply(duringRead).status == .cancelled && writes == 0, "cancel during admission writes zero")
        let cancelledRestart = ChargeControlCoordinator(journal: duringJournal,
            backend: backend(read: { state(80) }, write: { _ in fatalError("cancelled restart must not write") }),
            rival: { false })
        check(!cancelledRestart.requiresRecovery, "cancelled journal does not lock restart")

        let lateRequest = ChargeControlCoordinator.Request(85, source: .manual)
        limit = 80
        let lateCancel = ChargeControlCoordinator(journal: path(), backend: backend(read: { state(limit) }, write: {
            writes += 1; limit = $0; lateRequest.cancel(); return state(limit)
        }), rival: { false })
        let lateResult = lateCancel.apply(lateRequest)
        check(lateResult.status == .configurationVerified && lateResult.message.contains("başladıktan"),
              "late cancellation reports confirmed outcome without rollback")

        let invalidParent = path()
        try Data("not-a-directory".utf8).write(to: invalidParent)
        let denied = ChargeControlCoordinator(journal: invalidParent.appendingPathComponent("session.json"),
            backend: backend(read: { state(80) }, write: { _ in writes += 1; return state(85) }), rival: { false })
        let writesBeforeDenied = writes
        check(denied.apply(85).status == .rejected && writes == writesBeforeDenied,
              "journal failure before writer rejects")

        var reentrant: ChargeControlCoordinator!
        var nested: ChargeControlCoordinator.Status?
        limit = 80
        reentrant = ChargeControlCoordinator(journal: path(), backend: backend(read: { state(limit) }, write: {
            nested = reentrant.apply(90).status
            writes += 1; limit = $0; return state(limit)
        }), rival: { false })
        check(reentrant.apply(85).status == .configurationVerified && nested == .busy,
              "reentrant request sees busy and cannot write twice")

        let corruptBefore = try Data(contentsOf: corrupt)
        check(broken.reconcile(expectedLimit: 80).status == .reconciled, "corrupt journal can be reconciled explicitly")
        let allBackups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("control-session-before-recovery-") }
        let corruptPreserved = try allBackups.contains { try Data(contentsOf: $0) == corruptBefore }
        check(corruptPreserved, "corrupt evidence backed up byte for byte")

        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let done = DispatchSemaphore(value: 0)
        let concurrent = ChargeControlCoordinator(journal: path(), backend: backend(read: {
            entered.signal(); _ = release.wait(timeout: .now() + 3); return state(80)
        }, write: { _ in fatalError("unsupported concurrent fixture must never write") }), rival: { false })
        DispatchQueue.global().async {
            _ = concurrent.apply(ChargeControlCoordinator.Request(50, source: .manual)); done.signal()
        }
        check(entered.wait(timeout: .now() + 3) == .success && concurrent.isBusy, "busy true while admitted")
        check(concurrent.apply(ChargeControlCoordinator.Request(85, source: .schedule)).status == .busy,
              "concurrent schedule rejected")
        release.signal()
        check(done.wait(timeout: .now() + 3) == .success && !concurrent.isBusy, "busy false after completion")

        print("Coordinator: \(count) assertions passed; typed fake backend only.")
    }

    private struct TestEnvelope: Encodable {
        let schemaVersion: Int
        let ok: Bool
        let state: NativeChargeState
    }
}
