import SwiftUI
import AppKit

extension Notification.Name {
    static let chargeMatePanelClosed = Notification.Name("ChargeMatePanelClosed")
    static let chargeMateSettingsPage = Notification.Name("ChargeMateSettingsPage")
}

/// All drawing inputs are values; pointer updates never fetch battery data.
struct HistoryPlot: View, Equatable {
    let data: ChartData
    let metric: BatteryMetric
    let hours: Int
    let height: CGFloat
    let detailProgress: Double
    var limitEvents: [LimitEvent] = []
    var onHoverChanged: (Bool) -> Void = { _ in }
    @State private var selectedDate: Date?
    @State private var pointerMode = true
    @State private var missing = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data && lhs.metric == rhs.metric && lhs.hours == rhs.hours && lhs.height == rhs.height
            && lhs.detailProgress == rhs.detailProgress && lhs.limitEvents == rhs.limitEvents
    }

    private var selected: ChartSample? { data.samples.first { $0.date == selectedDate } }

    var body: some View {
        let selection = selected
        GeometryReader { geometry in
            let plot = ChartData.plot(in: geometry.size, detailProgress: detailProgress)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    Self.draw(data: data, metric: metric, selected: selection, limits: limitEvents,
                              hours: hours, detailProgress: detailProgress, context: &context, size: size)
                }.allowsHitTesting(false)
                if data.samples.isEmpty {
                    Text("Bu aralıkta ölçüm yok")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(width: plot.width, height: plot.height).offset(x: plot.minX, y: plot.minY)
                        .allowsHitTesting(false)
                }
                ChartInput(label: String(localized: "\(metric.title) grafiği"), value: selectionText,
                           onPointer: { inspect($0, plot: plot) }, onCommand: navigate,
                           onKeyboardFocus: { onHoverChanged($0) }, onHoverChanged: onHoverChanged)
                if let selection, let value = selection.value {
                    let position = data.position(selection, plot: plot)
                    VStack(spacing: 2) {
                        Text(metric.hoverText(value)).font(.system(size: 13, weight: .bold))
                        Text(selectionDate(selection.date)).font(.system(size: 11, weight: .medium))
                    }
                    .monospacedDigit().frame(width: 106, height: 44)
                    .modifier(GlassSurface(radius: 11))
                    .position(x: ChartData.labelX(position.x, plot: plot), y: plot.minY + 24)
                    .allowsHitTesting(false)
                }
            }
        }.frame(height: height)
        .onReceive(NotificationCenter.default.publisher(for: .chargeMatePanelClosed)) { _ in
            clear(); onHoverChanged(false)
        }
        .onChange(of: data.samples.map(\.date)) { dates in
            if let selectedDate, !dates.contains(selectedDate) { clear() }
        }
    }

    private var selectionText: String {
        if let sample = selected, let value = sample.value {
            return "\(sample.date.formatted(date: .omitted, time: .shortened)) · \(metric.hoverText(value))"
        }
        if missing { return String(localized: "Bu aralıkta ölçüm yok") }
        if data.samples.isEmpty { return String(localized: "Ölçüm toplanıyor…") }
        if data.samples.count < 5 { return String(localized: "\(data.samples.count) gerçek ölçüm · Veri birikiyor") }
        return String(localized: "\(data.samples.count) ölçüm · Son \(hours) saat")
    }

    private func selectionDate(_ date: Date) -> String {
        if hours <= 1 { return date.formatted(.dateTime.hour().minute()) }
        return date.formatted(.dateTime.day().month().year().hour().minute())
    }

    private func clear() { selectedDate = nil; missing = false }

    private func inspect(_ point: CGPoint?, plot: CGRect) {
        guard let point, let date = data.date(at: point, plot: plot) else {
            if pointerMode { clear() }
            return
        }
        pointerMode = true
        let nearest = data.nearest(to: date)
        if selectedDate != nearest?.date { selectedDate = nearest?.date }
        if missing != (nearest == nil) { missing = nearest == nil }
    }

    private func navigate(_ key: UInt16) -> Bool {
        if key == 53 {
            guard selectedDate != nil || missing else { return false }
            clear(); return true
        }
        guard !data.samples.isEmpty else { return false }
        let current = data.samples.firstIndex { $0.date == selectedDate }
        let index: Int
        switch key {
        case 123, 125: index = max(0, (current ?? data.samples.count) - 1)
        case 124, 126: index = min(data.samples.count - 1, (current ?? -1) + 1)
        case 115: index = 0
        case 119: index = data.samples.count - 1
        default: return false
        }
        pointerMode = false; missing = false; selectedDate = data.samples[index].date
        return true
    }

    private static func draw(data: ChartData, metric: BatteryMetric, selected: ChartSample?, limits: [LimitEvent], hours: Int, detailProgress: Double, context: inout GraphicsContext, size: CGSize) {
        let opacity = ChartPresentation.detailOpacity(detailProgress)
        let plot = ChartData.plot(in: size, detailProgress: detailProgress)
        for fraction in [0.0, 0.5, 1.0] {
            let y = plot.maxY - plot.height * fraction
            var grid = Path(); grid.move(to: CGPoint(x: plot.minX, y: y)); grid.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(grid, with: .color(.primary.opacity(0.12 * opacity)), lineWidth: 1)
            let value = data.yDomain.lowerBound + fraction * (data.yDomain.upperBound - data.yDomain.lowerBound)
            context.draw(Text(ChartPresentation.axisLabel(value, domain: data.yDomain)).font(.system(size: 10)).foregroundColor(Color.secondary.opacity(opacity)), at: CGPoint(x: plot.minX - 6, y: y), anchor: .trailing)
        }
        if hours >= 24 {
            let middle = data.xDomain.lowerBound.addingTimeInterval(data.xDomain.upperBound.timeIntervalSince(data.xDomain.lowerBound) / 2)
            context.draw(axisDate(data.xDomain.lowerBound, opacity: opacity), at: CGPoint(x: plot.minX, y: plot.maxY + 13), anchor: .leading)
            context.draw(axisDate(middle, opacity: opacity), at: CGPoint(x: plot.midX, y: plot.maxY + 13), anchor: .center)
            context.draw(axisDate(data.xDomain.upperBound, opacity: opacity), at: CGPoint(x: plot.maxX, y: plot.maxY + 13), anchor: .trailing)
        } else {
            context.draw(axisTime(data.xDomain.lowerBound, opacity: opacity), at: CGPoint(x: plot.minX, y: plot.maxY + 13), anchor: .leading)
            context.draw(axisTime(data.xDomain.upperBound, opacity: opacity), at: CGPoint(x: plot.maxX, y: plot.maxY + 13), anchor: .trailing)
        }
        for segment in data.segments {
            var line = Path()
            for (index, sample) in segment.enumerated() {
                let point = data.position(sample, plot: plot)
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            if let first = segment.first, let last = segment.last, segment.count > 1 {
                var area = line
                area.addLine(to: CGPoint(x: data.position(last, plot: plot).x, y: plot.maxY))
                area.addLine(to: CGPoint(x: data.position(first, plot: plot).x, y: plot.maxY)); area.closeSubpath()
                let fill = Gradient(stops: [
                    .init(color: metric.color.opacity(0.18), location: 0),
                    .init(color: metric.color.opacity(0.06), location: 0.55),
                    .init(color: metric.color.opacity(0), location: 1)
                ])
                let lineTop = segment.map { data.position($0, plot: plot).y }.min() ?? plot.minY
                context.fill(area, with: .linearGradient(fill, startPoint: CGPoint(x: 0, y: lineTop), endPoint: CGPoint(x: 0, y: plot.maxY)))
            }
            context.stroke(line, with: .color(metric.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            if segment.count == 1, let sample = segment.first {
                let p = data.position(sample, plot: plot)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(metric.color))
            }
        }
        if metric == .level {
            var step = Path()
            for (index, event) in limits.enumerated() {
                let end = index + 1 < limits.count ? limits[index + 1].date : data.xDomain.upperBound
                guard event.date <= data.xDomain.upperBound, end >= data.xDomain.lowerBound else { continue }
                let start = data.position(ChartSample(date: max(event.date, data.xDomain.lowerBound), value: Double(event.value)), plot: plot)
                let finish = data.position(ChartSample(date: min(end, data.xDomain.upperBound), value: Double(event.value)), plot: plot)
                if step.isEmpty { step.move(to: start) } else { step.addLine(to: start) }
                step.addLine(to: finish)
            }
            context.stroke(step, with: .color(.orange.opacity(opacity)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        if let selected {
            let point = data.position(selected, plot: plot)
            var guide = Path(); guide.move(to: CGPoint(x: point.x, y: plot.minY)); guide.addLine(to: CGPoint(x: point.x, y: plot.maxY))
            context.stroke(guide, with: .color(.primary.opacity(0.5)), lineWidth: 1)
            let dot = Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
            context.fill(dot, with: .color(metric.color)); context.stroke(dot, with: .color(.white), lineWidth: 1.5)
        }
    }

    private static func axisDate(_ date: Date, opacity: Double) -> Text {
        Text(date, format: .dateTime.day().month().year())
            .font(.system(size: 10)).foregroundColor(Color.secondary.opacity(opacity))
    }

    private static func axisTime(_ date: Date, opacity: Double) -> Text {
        Text(date, format: .dateTime.hour().minute())
            .font(.system(size: 10)).foregroundColor(Color.secondary.opacity(opacity))
    }
}

private struct ChartInput: NSViewRepresentable {
    let label: String
    let value: String
    let onPointer: (CGPoint?) -> Void
    let onCommand: (UInt16) -> Bool
    let onKeyboardFocus: (Bool) -> Void
    let onHoverChanged: (Bool) -> Void
    func makeNSView(context: Context) -> ChartTrackingView { ChartTrackingView() }
    func updateNSView(_ view: ChartTrackingView, context: Context) {
        view.onPointer = onPointer; view.onCommand = onCommand; view.onKeyboardFocus = onKeyboardFocus; view.onHoverChanged = onHoverChanged
        view.setAccessibilityElement(true); view.setAccessibilityRole(.image)
        view.setAccessibilityLabel(label); view.setAccessibilityValue(value)
        view.setAccessibilityHelp(String(localized: "Fareyle inceleyin veya tıklayıp yön tuşlarını kullanın. Home/End ilk/son ölçüm; Escape seçimi temizler."))
    }
}

final class ChartTrackingView: NSView {
    var onPointer: (CGPoint?) -> Void = { _ in }
    var onCommand: (UInt16) -> Bool = { _ in false }
    var onKeyboardFocus: (Bool) -> Void = { _ in }
    var onHoverChanged: (Bool) -> Void = { _ in }
    private var movementMonitor: Any?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        reconcileHover()
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reconcileHover()
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { resetHover() }
        super.viewWillMove(toWindow: newWindow)
    }
    override func mouseMoved(with event: NSEvent) { updatePointer(event.locationInWindow) }
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { resetHover() }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onKeyboardFocus(false)
        mouseMoved(with: event)
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func keyDown(with event: NSEvent) {
        onKeyboardFocus(true)
        if !onCommand(event.keyCode) { super.keyDown(with: event) }
    }
    override func becomeFirstResponder() -> Bool {
        onKeyboardFocus(NSApp.currentEvent?.type == .keyDown)
        return true
    }
    override func resignFirstResponder() -> Bool { onKeyboardFocus(false); return true }
    override func accessibilityPerformIncrement() -> Bool { onCommand(124) }
    override func accessibilityPerformDecrement() -> Bool { onCommand(123) }

    deinit { stopMovementMonitor() }

    private func reconcileHover() {
        guard let window else { resetHover(); return }
        updatePointer(window.mouseLocationOutsideOfEventStream)
    }

    func updatePointer(_ locationInWindow: CGPoint) {
        let point = convert(locationInWindow, from: nil)
        guard visibleRect.contains(point) else { resetHover(); return }
        startMovementMonitor()
        onHoverChanged(true)
        onPointer(point)
    }

    private func startMovementMonitor() {
        guard movementMonitor == nil else { return }
        movementMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.updatePointer(event.locationInWindow)
            return event
        }
    }

    private func stopMovementMonitor() {
        if let movementMonitor { NSEvent.removeMonitor(movementMonitor) }
        movementMonitor = nil
    }

    private func resetHover() {
        stopMovementMonitor()
        onPointer(nil)
        onHoverChanged(false)
    }
}
