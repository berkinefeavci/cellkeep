import Foundation
import IOKit

struct USBDeviceRecord {
    let locationID: Int?
    let vendorID: Int?
    let productID: Int?
    let productName: String?
    let vendorName: String?
    let deviceClass: Int?
    let interfaceClasses: [Int]
    var bsdDisk: String? = nil
}

enum ConnectedDeviceKind: Int, Equatable {
    case phone, storage, hub, audio, camera, other

    var title: String {
        switch self {
        case .phone: return String(localized: "Telefon")
        case .storage: return String(localized: "Harici depolama")
        case .hub: return String(localized: "USB çoklayıcı")
        case .audio: return String(localized: "Ses cihazı")
        case .camera: return String(localized: "Kamera")
        case .other: return String(localized: "USB cihazı")
        }
    }

    var icon: String {
        switch self {
        case .phone: return "iphone"
        case .storage: return "externaldrive.fill"
        case .hub: return "cable.connector"
        case .audio: return "headphones"
        case .camera: return "video.fill"
        case .other: return "usb.drive.fill"
        }
    }
}

struct ConnectedDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let vendor: String?
    let kind: ConnectedDeviceKind
    var diskIdentifier: String? = nil
    var powerWatts: Double? = nil

    var canEject: Bool { kind == .storage && Self.canEject(identifier: diskIdentifier) }

    static func canEject(identifier: String?) -> Bool {
        guard let identifier, identifier.hasPrefix("disk"), identifier != "disk0" else { return false }
        return !identifier.dropFirst(4).isEmpty && identifier.dropFirst(4).allSatisfy(\.isNumber)
    }

    var detail: String {
        let vendor = vendor?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [kind.title, vendor?.isEmpty == false ? vendor : nil, String(localized: "USB ile bağlı")]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

// AppleSmartBattery's read-only PowerOutDetails: power the Mac delivers out of each port.
struct PortPowerSample: Equatable {
    let portIndex: Int
    let watts: Double
}

enum PortPowerOutput {
    // Below this, a port is idle/noise, not delivered power.
    static let minimumWatts = 0.1
    // A device is only attributed a port's wattage when the port clears this.
    static let activeThreshold = 0.3

    static func samples(from entries: [[String: Any]]) -> [PortPowerSample] {
        entries.compactMap { entry -> PortPowerSample? in
            guard let portIndex = int(entry["PortIndex"]), let watts = watts(from: entry),
                  watts.isFinite, watts > minimumWatts else { return nil }
            return PortPowerSample(portIndex: portIndex, watts: watts)
        }
    }

    // If exactly one device is connected and exactly one port is actively delivering
    // power, that port's wattage belongs to that device. Otherwise never guess.
    static func attribute(samples: [PortPowerSample], deviceCount: Int) -> Double? {
        guard deviceCount == 1 else { return nil }
        let active = samples.filter { $0.watts > activeThreshold }
        guard active.count == 1 else { return nil }
        return active[0].watts
    }

    private static func watts(from entry: [String: Any]) -> Double? {
        if let milliwatts = double(entry["Watts"]), milliwatts.isFinite, milliwatts >= 0 {
            return milliwatts / 1000
        }
        if let current = double(entry["Current"]), let voltage = double(entry["AdapterVoltage"]),
           current.isFinite, voltage.isFinite, current > 0, voltage > 0 {
            return (current / 1000) * (voltage / 1000)
        }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Int { return value }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? Double { return value }
        return nil
    }
}

enum ConnectedDeviceReader {
    static func validatedEjectIdentifier(_ selected: ConnectedDevice, current: [ConnectedDevice]) -> String? {
        guard selected.canEject,
              current.contains(where: { $0.id == selected.id && $0.diskIdentifier == selected.diskIdentifier }) else { return nil }
        return selected.diskIdentifier
    }

    static func eject(_ selected: ConnectedDevice) -> String? {
        guard let disk = validatedEjectIdentifier(selected, current: read()) else {
            return String(localized: "Disk artık aynı bağlantıda bulunamadı; çıkarma yapılmadı.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["eject", disk]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return nil }
            let message = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? String(localized: "Disk çıkarılamadı; açık dosyaları kapatıp yeniden deneyin.")
                : message.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return String(localized: "Disk çıkarılamadı: \(error.localizedDescription)")
        }
    }

    static func read() -> [ConnectedDevice] {
        guard let matching = IOServiceMatching("IOUSBHostDevice") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var records: [USBDeviceRecord] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let properties = properties(of: service) {
                records.append(USBDeviceRecord(
                    locationID: integer(properties["locationID"]),
                    vendorID: integer(properties["idVendor"]),
                    productID: integer(properties["idProduct"]),
                    productName: string(properties["USB Product Name"]) ?? registryName(of: service),
                    vendorName: string(properties["USB Vendor Name"]),
                    deviceClass: integer(properties["bDeviceClass"]),
                    interfaceClasses: interfaceClasses(below: service),
                    bsdDisk: wholeDisk(below: service)
                ))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        var result = devices(from: records)
        if let watts = PortPowerOutput.attribute(samples: portPowerSamples(), deviceCount: result.count) {
            result[0].powerWatts = watts
        }
        return result
    }

    // AppleSmartBattery.PowerOutDetails is read-only and password-free; never write to it.
    private static func portPowerSamples() -> [PortPowerSample] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [] }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(service, "PowerOutDetails" as CFString, kCFAllocatorDefault, 0),
              let entries = property.takeRetainedValue() as? [[String: Any]] else { return [] }
        return PortPowerOutput.samples(from: entries)
    }

    static func devices(from records: [USBDeviceRecord]) -> [ConnectedDevice] {
        var seen = Set<String>()
        return records.compactMap { record in
            let name = record.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty else { return nil }
            let id = "usb-\(record.locationID ?? -1)-\(record.vendorID ?? -1)-\(record.productID ?? -1)-\(name)"
            guard seen.insert(id).inserted else { return nil }
            return ConnectedDevice(id: id, name: name, vendor: record.vendorName,
                                   kind: kind(for: record, name: name), diskIdentifier: record.bsdDisk)
        }.sorted {
            $0.kind.rawValue == $1.kind.rawValue
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.kind.rawValue < $1.kind.rawValue
        }
    }

    private static func kind(for record: USBDeviceRecord, name: String) -> ConnectedDeviceKind {
        let value = name.lowercased()
        if value.contains("iphone") || value.contains("ipad") || value.contains("phone") || value.contains("telefon") {
            return .phone
        }
        if record.interfaceClasses.contains(8)
            || ["ssd", "flash", "storage", "drive", "disk", "datatraveler", "memory"].contains(where: value.contains) {
            return .storage
        }
        if record.deviceClass == 9 || value.contains("hub") { return .hub }
        if record.interfaceClasses.contains(1) { return .audio }
        if record.interfaceClasses.contains(6) || record.interfaceClasses.contains(14) || value.contains("camera") { return .camera }
        return .other
    }

    private static func properties(of entry: io_registry_entry_t) -> [String: Any]? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = unmanaged?.takeRetainedValue() else { return nil }
        return dictionary as NSDictionary as? [String: Any]
    }

    private static func interfaceClasses(below entry: io_registry_entry_t) -> [Int] {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [Int] = []
        var child = IOIteratorNext(iterator)
        while child != 0 {
            if let properties = properties(of: child), let value = integer(properties["bInterfaceClass"]) {
                result.append(value)
            }
            result += interfaceClasses(below: child)
            IOObjectRelease(child)
            child = IOIteratorNext(iterator)
        }
        return Array(Set(result)).sorted()
    }

    private static func wholeDisk(below entry: io_registry_entry_t) -> String? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var child = IOIteratorNext(iterator)
        while child != 0 {
            let props = properties(of: child)
            let disk = (props?["Whole"] as? Bool == true) ? string(props?["BSD Name"]) : nil
            let result = disk ?? wholeDisk(below: child)
            IOObjectRelease(child)
            if let result { return result }
            child = IOIteratorNext(iterator)
        }
        return nil
    }

    private static func registryName(of entry: io_registry_entry_t) -> String? {
        var name = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &name) == KERN_SUCCESS else { return nil }
        return String(cString: name)
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Int { return value }
        return nil
    }

    private static func string(_ value: Any?) -> String? { value as? String }
}
