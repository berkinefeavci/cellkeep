import Foundation

@main
enum ConnectedDeviceTests {
    static func main() {
        let records = [
            USBDeviceRecord(locationID: 1, vendorID: 1452, productID: 4776,
                            productName: "iPhone", vendorName: "Apple Inc.",
                            deviceClass: 0, interfaceClasses: [6, 2, 10]),
            USBDeviceRecord(locationID: 1, vendorID: 1452, productID: 4776,
                            productName: "iPhone", vendorName: "Apple Inc.",
                            deviceClass: 0, interfaceClasses: [6]),
            USBDeviceRecord(locationID: 2, vendorID: 999, productID: 12,
                            productName: "Portable SSD", vendorName: "Example",
                            deviceClass: 0, interfaceClasses: [8]),
            USBDeviceRecord(locationID: 3, vendorID: 111, productID: 22,
                            productName: "DataTraveler", vendorName: "Kingston",
                            deviceClass: 0, interfaceClasses: [8])
        ]

        let devices = ConnectedDeviceReader.devices(from: records)
        precondition(devices.count == 3, "A physical USB device must appear once")
        precondition(devices.first(where: { $0.name == "iPhone" })?.kind == .phone)
        precondition(devices.first(where: { $0.name == "Portable SSD" })?.kind == .storage)
        precondition(devices.first(where: { $0.name == "DataTraveler" })?.kind == .storage)
        precondition(devices.allSatisfy { !$0.detail.lowercased().contains("serial") },
                     "Private serial data must not enter presentation models")

        var mounted = records[2]
        mounted.bsdDisk = "disk4"
        let ejectable = ConnectedDeviceReader.devices(from: [records[0], mounted])
        precondition(ejectable.first(where: { $0.name == "Portable SSD" })?.diskIdentifier == "disk4",
                     "A USB storage device must retain its own whole-disk identifier")
        precondition(ejectable.first(where: { $0.name == "iPhone" })?.canEject == false,
                     "A phone must not offer disk eject")
        precondition(ConnectedDevice.canEject(identifier: "disk4"))
        precondition(!ConnectedDevice.canEject(identifier: "disk4s1") && !ConnectedDevice.canEject(identifier: "disk0"),
                     "Only removable external whole-disk identifiers can be passed to eject")
        let selected = ejectable.first(where: { $0.name == "Portable SSD" })!
        precondition(ConnectedDeviceReader.validatedEjectIdentifier(selected, current: ejectable) == "disk4")
        precondition(ConnectedDeviceReader.validatedEjectIdentifier(selected, current: [ejectable[0]]) == nil,
                     "A stale device selection must not eject a different disk")

        // Live sample from AppleSmartBattery's PowerOutDetails (iPhone on port 1, mW units).
        let liveEntry: [String: Any] = [
            "PowerState": 0, "PortIndex": 1, "Watts": 10033, "Current": 1924, "AdapterVoltage": 5212,
            "FilteredPower": 9839, "PDPowermW": 15000, "ConfiguredCurrent": 3000, "ConfiguredVoltage": 5000,
            "AccumulatedPower": 27689036, "AccumulatorCount": 2982, "PortType": 0, "VConnPower": 74
        ]
        let liveSamples = PortPowerOutput.samples(from: [liveEntry])
        precondition(liveSamples.count == 1 && liveSamples[0].portIndex == 1, "Sample port must be parsed")
        precondition(abs(liveSamples[0].watts - 10.033) < 0.001, "Watts (mW) must convert to W")

        // Idle/zero entries carry no delivered power and must be ignored.
        let idleEntry: [String: Any] = ["PortIndex": 2, "Watts": 0, "Current": 0, "AdapterVoltage": 0]
        precondition(PortPowerOutput.samples(from: [idleEntry]).isEmpty, "Zero-power ports must be ignored")

        // Fallback: Watts missing, computed from Current (mA) x AdapterVoltage (mV).
        let fallbackEntry: [String: Any] = ["PortIndex": 3, "Current": 1000, "AdapterVoltage": 5000]
        let fallbackSamples = PortPowerOutput.samples(from: [fallbackEntry])
        precondition(fallbackSamples.count == 1 && abs(fallbackSamples[0].watts - 5.0) < 0.001,
                     "Missing Watts must fall back to Current x AdapterVoltage")

        // Missing keys or empty array must yield no samples, never a guess.
        precondition(PortPowerOutput.samples(from: []).isEmpty)
        precondition(PortPowerOutput.samples(from: [["PortIndex": 4]]).isEmpty, "No usable value must not fabricate power")
        precondition(PortPowerOutput.samples(from: [["Watts": 5000]]).isEmpty, "Missing PortIndex must be ignored")

        // Attribution: exactly one device + exactly one active port -> assign; otherwise nil.
        let onePort = [PortPowerSample(portIndex: 1, watts: 10.0)]
        precondition(PortPowerOutput.attribute(samples: onePort, deviceCount: 1) == 10.0,
                     "Single device with single active port must receive the measured wattage")
        precondition(PortPowerOutput.attribute(samples: onePort, deviceCount: 2) == nil,
                     "Multiple connected devices must not guess which one is powered")
        precondition(PortPowerOutput.attribute(samples: [], deviceCount: 1) == nil,
                     "Zero active ports must not fabricate a value")
        let twoPorts = [PortPowerSample(portIndex: 1, watts: 10.0), PortPowerSample(portIndex: 2, watts: 5.0)]
        precondition(PortPowerOutput.attribute(samples: twoPorts, deviceCount: 1) == nil,
                     "Multiple active ports must not be collapsed onto one device")
        let belowThreshold = [PortPowerSample(portIndex: 1, watts: 0.2)]
        precondition(PortPowerOutput.attribute(samples: belowThreshold, deviceCount: 1) == nil,
                     "A port at or below the active threshold must not count as delivering power")

        print("PASS: connected USB devices are deduplicated and described without serial data")
        if CommandLine.arguments.contains("--live") {
            let live = ConnectedDeviceReader.read()
            print("LIVE:", live.map { "\($0.name) [\($0.kind.title)]" }.joined(separator: ", "))
        }
    }
}
