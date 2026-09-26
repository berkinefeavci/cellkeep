import AppKit

@main
enum PowerModeComparison {
    static func main() throws {
        guard CommandLine.arguments.count == 4,
              let reference = NSImage(contentsOfFile: CommandLine.arguments[1]),
              let implementation = NSImage(contentsOfFile: CommandLine.arguments[2]) else {
            fatalError("Usage: PowerModeComparison reference.png implementation.png output.png")
        }

        let canvasSize = NSSize(width: 900, height: 760)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = canvasSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        drawLabel("KAYNAK — kullanıcının yerleşim referansı", y: 714)
        let referenceFrame = NSRect(x: 68, y: 444, width: 764, height: 236)
        reference.draw(in: referenceFrame)

        drawLabel("UYGULAMA — aynı kart, güç modu kontrolleri eklendi", y: 392)
        // The implementation render is 800x1400 pixels at 2x (400x700 points).
        // Crop the status card in AppKit's bottom-left point coordinates.
        let sourceRect = NSRect(x: 16, y: 406.5, width: 368, height: 147)
        implementation.draw(in: NSRect(x: 68, y: 60, width: 764, height: 305),
                            from: sourceRect, operation: .sourceOver, fraction: 1)

        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
    }

    private static func drawLabel(_ value: String, y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 1)
        ]
        value.draw(at: NSPoint(x: 68, y: y), withAttributes: attributes)
    }
}
