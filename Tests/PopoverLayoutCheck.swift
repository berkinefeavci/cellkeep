import Foundation

@main struct PopoverLayoutCheck {
    static func main() throws {
        let legacy: [PanelWidget] = [.statusExplanation, .specifications, .chartLevel]
        precondition(PopoverLayout.decode(Data(), legacy: legacy).items == legacy.map { PlacedWidget($0) })
        var draft = legacy.map { PlacedWidget($0) }
        draft.append(PlacedWidget(.chartCycles))
        draft = PopoverLayout.move(.chartCycles, before: .statusExplanation, in: draft)
        draft.removeAll { $0.widget == .specifications }
        let saved = try PopoverLayout.encode(draft)
        precondition(PopoverLayout.decode(saved, legacy: legacy).items.map(\.widget) == [.chartCycles, .statusExplanation, .chartLevel])
        let empty = try PopoverLayout.encode([])
        precondition(PopoverLayout.decode(empty, legacy: legacy).items.isEmpty)
        let corrupt = Data("broken".utf8)
        precondition(PopoverLayout.decode(corrupt, legacy: legacy).notice != nil)
        let unknown = try JSONEncoder().encode(
            PopoverLayout(schemaVersion: 2, widgets: [PlacedWidget(.chartLevel), PlacedWidget(.chartLevel)]))
        precondition(PopoverLayout.decode(unknown, legacy: legacy).items.map(\.widget) == [.chartLevel])
        // Editing a copy leaves the committed JSON untouched until explicit save.
        let original = saved
        draft.removeAll()
        precondition(saved == original && !PopoverLayout.decode(saved, legacy: legacy).items.isEmpty)

        // --- Size model: default, per-type support, migration ---
        precondition(PlacedWidget(.chartLevel).size == .wide, "default size is .wide")
        precondition(PlacedWidget(.chartLevel, size: .square).size == .square)
        // A type that only supports .wide silently clamps an invalid .square request.
        precondition(PlacedWidget(.powerFlow, size: .square).size == .wide)
        precondition(PanelWidget.chartLevel.supportedSizes == [.wide, .square])
        precondition(PanelWidget.powerFlow.supportedSizes == [.wide])
        precondition(PanelWidget.powerMode.supportedSizes == [.wide])
        precondition(PanelWidget.statusExplanation.supportedSizes == [.wide])
        precondition(PanelWidget.significantEnergy.supportedSizes == [.wide, .square])
        precondition(PanelWidget.specifications.supportedSizes == [.wide, .square])

        // Old schemaVersion 1 data (plain widget-name strings) decodes as .wide with no loss.
        struct LegacyV1: Codable { let schemaVersion: Int; let widgets: [String] }
        let legacyV1 = try JSONEncoder().encode(LegacyV1(schemaVersion: 1, widgets: ["chartLevel", "significantEnergy"]))
        let migrated = PopoverLayout.decode(legacyV1, legacy: legacy)
        precondition(migrated.items == [PlacedWidget(.chartLevel, size: .wide), PlacedWidget(.significantEnergy, size: .wide)])
        precondition(migrated.notice == nil)

        // Round-trip a mixed-size layout through encode/decode (schemaVersion 2).
        let mixed = [PlacedWidget(.chartLevel, size: .square), PlacedWidget(.powerFlow), PlacedWidget(.chartTemperature, size: .square)]
        let mixedData = try PopoverLayout.encode(mixed)
        precondition(PopoverLayout.decode(mixedData, legacy: legacy).items == mixed)

        // A saved payload missing the "size" key (hand-written/older-shape JSON) still decodes,
        // defaulting to .wide.
        let sparseJSON = Data(#"{"schemaVersion":2,"widgets":[{"widget":"chartLevel"},{"widget":"specifications","size":"square"}]}"#.utf8)
        let sparse = PopoverLayout.decode(sparseJSON, legacy: legacy)
        precondition(sparse.items == [PlacedWidget(.chartLevel, size: .wide), PlacedWidget(.specifications, size: .square)])
        precondition(sparse.notice == nil)

        // --- Grid pairing: pure function mapping widgets -> rows ---
        let onlyWide = [PlacedWidget(.powerFlow), PlacedWidget(.powerMode)]
        precondition(PopoverLayout.rows(for: onlyWide) == [.wide(onlyWide[0]), .wide(onlyWide[1])])

        let twoSquares = [PlacedWidget(.chartLevel, size: .square), PlacedWidget(.chartTemperature, size: .square)]
        precondition(PopoverLayout.rows(for: twoSquares) == [.squarePair(twoSquares[0], twoSquares[1])])

        let loneSquare = [PlacedWidget(.chartLevel, size: .square)]
        precondition(PopoverLayout.rows(for: loneSquare) == [.squareSingle(loneSquare[0])])

        // Odd-one-out: three consecutive squares pair the first two, leave the third alone.
        let threeSquares = [PlacedWidget(.chartLevel, size: .square), PlacedWidget(.chartTemperature, size: .square),
                             PlacedWidget(.chartPower, size: .square)]
        precondition(PopoverLayout.rows(for: threeSquares) == [
            .squarePair(threeSquares[0], threeSquares[1]), .squareSingle(threeSquares[2]),
        ])

        // Wide/square mix keeps order: a lone square between two wides takes its own row.
        let mixedRows = [PlacedWidget(.powerFlow), PlacedWidget(.chartLevel, size: .square), PlacedWidget(.powerMode)]
        precondition(PopoverLayout.rows(for: mixedRows) == [
            .wide(mixedRows[0]), .squareSingle(mixedRows[1]), .wide(mixedRows[2]),
        ])

        print("PASS: layout migration/add/move/remove/round-trip/cancel/empty/unknown/corrupt/size/grid")
    }
}
