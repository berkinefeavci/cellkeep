import AppKit
import SwiftUI

struct LimitEvent: Equatable {
    let date: Date
    let value: Int
}

enum BatteryMetric: String, Equatable {
    case level = "Batarya seviyesi"
    var color: Color { .green }
    func hoverText(_ value: Double) -> String { String(format: "%.1f %%", value) }
}

struct GlassSurface: ViewModifier {
    init(radius: CGFloat = 20) {}
    func body(content: Content) -> some View { content }
}

@main
enum ChartHoverCheck {
    static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 200, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let view = ChartTrackingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        container.addSubview(view)
        window.contentView = container

        var hoverEvents = [true]
        var pointerWasCleared = false
        view.onHoverChanged = { hoverEvents.append($0) }
        view.onPointer = { pointerWasCleared = $0 == nil }
        view.updateTrackingAreas()

        precondition(hoverEvents.last == false)
        precondition(pointerWasCleared)

        view.updatePointer(NSPoint(x: 50, y: 50))
        precondition(hoverEvents.last == true,
                     "A point inside the chart must activate hover")
        pointerWasCleared = false
        view.updatePointer(NSPoint(x: 500, y: 500))
        precondition(hoverEvents.last == false,
                     "A window-level move outside the chart must clear hover instead of reactivating it")
        precondition(pointerWasCleared,
                     "Moving outside the chart must clear the selected sample")

        print("PASS: chart hover resets after geometry and window-level pointer changes")
    }
}
