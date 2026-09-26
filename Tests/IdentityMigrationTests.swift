import Foundation

/// In-memory fakes — no real UserDefaults domain and no real file system touched.
private final class FakeDefaultsDomain {
    var storage: [String: Any] = [:]
    var migrated = false
}

private final class FakeFileSystem {
    var directories: Set<String> = []
    var files: [String: Set<String>] = [:]   // directory -> file names
    var copies: [(String, String)] = []

    func exists(_ path: String) -> Bool {
        if directories.contains(path) { return true }
        let dir = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        return files[dir]?.contains(name) == true
    }
    func contents(_ dir: String) -> [String] { Array(files[dir] ?? []) }
    func createDirectory(_ path: String) { directories.insert(path) }
    func copy(_ from: String, _ to: String) {
        copies.append((from, to))
        let destDir = (to as NSString).deletingLastPathComponent
        let name = (to as NSString).lastPathComponent
        files[destDir, default: []].insert(name)
    }
}

private func makeStores(old: FakeDefaultsDomain, new: FakeDefaultsDomain) -> (IdentityMigration.OldDefaultsReading, IdentityMigration.NewDefaultsStore) {
    let oldReading = IdentityMigration.OldDefaultsReading(dictionaryRepresentation: { old.storage })
    let newStore = IdentityMigration.NewDefaultsStore(
        object: { new.storage[$0] },
        set: { new.storage[$1] = $0 },
        hasMigrated: { new.migrated },
        markMigrated: { new.migrated = true })
    return (oldReading, newStore)
}

@main enum IdentityMigrationTests {
    static func main() {
        let oldSupport = "/tmp/fake/Old"
        let newSupport = "/tmp/fake/New"

        // 1) First run copies defaults and files.
        do {
            let old = FakeDefaultsDomain()
            old.storage = ["chargeLimit": 80, "appearance": "dark"]
            let new = FakeDefaultsDomain()
            let fs = FakeFileSystem()
            fs.directories.insert(oldSupport)
            fs.files[oldSupport] = ["history.json", "charge-policy.json"]
            let (oldReading, newStore) = makeStores(old: old, new: new)
            let fileSystem = IdentityMigration.FileSystem(
                fileExists: fs.exists, contentsOfDirectory: fs.contents,
                createDirectoryIfNeeded: fs.createDirectory, copyItem: fs.copy)

            IdentityMigration.run(oldDefaults: oldReading, newDefaults: newStore,
                                   oldSupportDirectory: oldSupport, newSupportDirectory: newSupport,
                                   fileSystem: fileSystem)

            precondition(new.storage["chargeLimit"] as? Int == 80, "defaults value copied")
            precondition(new.storage["appearance"] as? String == "dark", "defaults value copied")
            precondition(new.migrated, "marker set after first run")
            precondition(fs.copies.count == 2, "both legacy files copied")
            precondition(fs.files[newSupport]?.contains("history.json") == true)
            precondition(fs.files[newSupport]?.contains("charge-policy.json") == true)
        }

        // 2) Second run no-ops: marker already set, nothing copied again.
        do {
            let old = FakeDefaultsDomain()
            old.storage = ["chargeLimit": 80]
            let new = FakeDefaultsDomain()
            new.migrated = true
            new.storage["chargeLimit"] = 55 // user already changed it under the new identity
            let fs = FakeFileSystem()
            fs.directories.insert(oldSupport)
            fs.files[oldSupport] = ["history.json"]
            let (oldReading, newStore) = makeStores(old: old, new: new)
            let fileSystem = IdentityMigration.FileSystem(
                fileExists: fs.exists, contentsOfDirectory: fs.contents,
                createDirectoryIfNeeded: fs.createDirectory, copyItem: fs.copy)

            IdentityMigration.run(oldDefaults: oldReading, newDefaults: newStore,
                                   oldSupportDirectory: oldSupport, newSupportDirectory: newSupport,
                                   fileSystem: fileSystem)

            precondition(new.storage["chargeLimit"] as? Int == 55, "existing new value untouched")
            precondition(fs.copies.isEmpty, "no-op: marker already set")
        }

        // 3) Existing new-domain value is never overwritten, even on a first (unmarked) run.
        do {
            let old = FakeDefaultsDomain()
            old.storage = ["chargeLimit": 80]
            let new = FakeDefaultsDomain()
            new.storage["chargeLimit"] = 42 // already present under the new identity somehow
            let fs = FakeFileSystem()
            let (oldReading, newStore) = makeStores(old: old, new: new)
            let fileSystem = IdentityMigration.FileSystem(
                fileExists: fs.exists, contentsOfDirectory: fs.contents,
                createDirectoryIfNeeded: fs.createDirectory, copyItem: fs.copy)

            IdentityMigration.run(oldDefaults: oldReading, newDefaults: newStore,
                                   oldSupportDirectory: oldSupport, newSupportDirectory: newSupport,
                                   fileSystem: fileSystem)

            precondition(new.storage["chargeLimit"] as? Int == 42, "pre-existing new value wins")
            precondition(new.migrated, "marker still set so this never runs twice")
        }

        // 4) A missing old data folder is fine — only defaults are migrated.
        do {
            let old = FakeDefaultsDomain()
            old.storage = ["appearance": "light"]
            let new = FakeDefaultsDomain()
            let fs = FakeFileSystem() // oldSupport directory never created
            let (oldReading, newStore) = makeStores(old: old, new: new)
            let fileSystem = IdentityMigration.FileSystem(
                fileExists: fs.exists, contentsOfDirectory: fs.contents,
                createDirectoryIfNeeded: fs.createDirectory, copyItem: fs.copy)

            IdentityMigration.run(oldDefaults: oldReading, newDefaults: newStore,
                                   oldSupportDirectory: oldSupport, newSupportDirectory: newSupport,
                                   fileSystem: fileSystem)

            precondition(new.storage["appearance"] as? String == "light")
            precondition(new.migrated)
            precondition(fs.copies.isEmpty, "nothing to copy when the old folder never existed")
        }

        // 5) A file already present in the new folder is never overwritten.
        do {
            let old = FakeDefaultsDomain()
            let new = FakeDefaultsDomain()
            let fs = FakeFileSystem()
            fs.directories.insert(oldSupport)
            fs.directories.insert(newSupport)
            fs.files[oldSupport] = ["history.json"]
            fs.files[newSupport] = ["history.json"] // user already has fresh data here
            let (oldReading, newStore) = makeStores(old: old, new: new)
            let fileSystem = IdentityMigration.FileSystem(
                fileExists: fs.exists, contentsOfDirectory: fs.contents,
                createDirectoryIfNeeded: fs.createDirectory, copyItem: fs.copy)

            IdentityMigration.run(oldDefaults: oldReading, newDefaults: newStore,
                                   oldSupportDirectory: oldSupport, newSupportDirectory: newSupport,
                                   fileSystem: fileSystem)

            precondition(fs.copies.isEmpty, "existing new-domain file is never overwritten")
        }

        print("Identity migration: copy-once, no-overwrite, missing-folder assertions passed.")
    }
}
