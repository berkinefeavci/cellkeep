import AppKit

@main
enum MenubarIconComparison {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            fatalError("Usage: comparison source.png output.png Cellkeep.app")
        }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        guard let source = NSImage(contentsOfFile: CommandLine.arguments[1]),
              let bundle = Bundle(path: CommandLine.arguments[3]) else { fatalError("Missing comparison input") }

        let now = Date()
        var snapshot = BatterySnapshot()
        snapshot.sampledAt = now
        snapshot.available = true
        snapshot.percentage = 90
        snapshot.externalConnected = true
        snapshot.batteryPowerAvailable = true
        snapshot.wattage = 0
        var preferences = MenubarPreferences()
        preferences.style = .iosBattery
        preferences.metrics = []
        let implementation = MenubarRenderer.render(
            MenubarPresentation(preferences: preferences, snapshot: snapshot, lowPower: false, now: now),
            maxWidth: 100,
            bundle: bundle
        ).image

        let width = Int(source.size.width) * 2
        let height = Int(source.size.height)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        source.draw(in: NSRect(x: 0, y: 0, width: source.size.width, height: source.size.height))
        NSColor(calibratedRed: 0.46, green: 0.42, blue: 0.40, alpha: 1).setFill()
        NSRect(x: source.size.width, y: 0, width: source.size.width, height: source.size.height).fill()
        implementation.draw(in: NSRect(
            x: source.size.width + (source.size.width - implementation.size.width * 2) / 2,
            y: (source.size.height - implementation.size.height * 2) / 2,
            width: implementation.size.width * 2,
            height: implementation.size.height * 2
        ))
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
