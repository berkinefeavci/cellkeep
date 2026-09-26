import Foundation

enum PanelWidget: String, CaseIterable, Codable, Identifiable {
    case statusExplanation, powerFlow, significantEnergy, powerMode, specifications
    case chartLevel, chartTemperature, chartPower, chartHealth, chartCycles
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .statusExplanation: return "Güncel şarj durumunun açıklaması"
        case .powerFlow: return "Adaptör, MacBook ve batarya arasındaki ölçülen güç"
        case .significantEnergy: return "En yüksek etkinliğe sahip uygulamalar"
        case .powerMode: return "Düşük Güç Modu açıkken görünen bilgi"
        case .specifications: return "Kapasite, döngü, sıcaklık ve güç özeti"
        case .chartLevel: return "Doluluk ve gözlenen limit değişimleri"
        case .chartTemperature: return "Gerçek sıcaklık ölçümleri, °C"
        case .chartPower: return "Ölçülen toplam sistem tüketimi, W"
        case .chartHealth: return "Maksimum kapasitenin tasarıma oranı, %"
        case .chartCycles: return "Ölçüm geçmişindeki döngü sayısı"
        }
    }
    var title: String {
        switch self {
        case .statusExplanation: return "Şarj durumu"
        case .powerFlow: return "Güç akışı"
        case .significantEnergy: return "Uygulama etkinliği"
        case .powerMode: return "Güç modu"
        case .specifications: return "Batarya bilgileri"
        case .chartLevel: return "Batarya seviyesi grafiği"
        case .chartTemperature: return "Sıcaklık grafiği"
        case .chartPower: return "Sistem gücü grafiği"
        case .chartHealth: return "Kapasite grafiği"
        case .chartCycles: return "Döngü grafiği"
        }
    }
    /// Bu kart türünün desteklediği boyutlar. `.wide` her zaman desteklenir;
    /// yalnızca burada listelenen türler `.square` (yarım genişlik) alabilir.
    var supportedSizes: Set<WidgetSize> {
        switch self {
        case .chartLevel, .chartTemperature, .chartPower, .chartHealth, .chartCycles,
             .specifications, .significantEnergy:
            return [.wide, .square]
        case .statusExplanation, .powerFlow, .powerMode:
            return [.wide]
        }
    }
}

/// Panele yerleştirilmiş bir kartın boyutu. `.wide` tam genişlik (eski davranış),
/// `.square` panel genişliğinin yarısı ve sabit ~150pt yükseklik.
enum WidgetSize: String, Codable, CaseIterable {
    case wide, square
}

/// Panele yerleştirilmiş tek bir kart: türü ve boyutu.
struct PlacedWidget: Codable, Equatable, Identifiable {
    var widget: PanelWidget
    var size: WidgetSize

    var id: PanelWidget { widget }

    init(_ widget: PanelWidget, size: WidgetSize = .wide) {
        self.widget = widget
        // Bilinmeyen/desteklenmeyen bir boyut hiçbir zaman kalıcı olmaz; her tür
        // en azından `.wide`'ı destekler, bu yüzden bu her zaman güvenli bir düşüş.
        self.size = widget.supportedSizes.contains(size) ? size : .wide
    }

    private enum CodingKeys: String, CodingKey { case widget, size }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let widget = try container.decode(PanelWidget.self, forKey: .widget)
        // Eski/eksik veri: `size` alanı yoksa (ya da tanınmıyorsa) `.wide` varsayılır — hiçbir
        // eski düzen kaybolmaz.
        let size: WidgetSize = (try? container.decode(WidgetSize.self, forKey: .size)) ?? .wide
        self.init(widget, size: size)
    }
}

/// Bir satırda yan yana gösterilecek kartlar. Saf, view-katmanından bağımsız bir eşleme:
/// ardışık `.square` kartlar ikişerli gruplanır (tek kalan kare tek başına, sol yarıda),
/// `.wide` kartlar kendi satırında tam genişlik alır. Sıra korunur.
enum WidgetRow: Equatable {
    case wide(PlacedWidget)
    case squarePair(PlacedWidget, PlacedWidget)
    case squareSingle(PlacedWidget)
}

struct PopoverLayout: Codable {
    let schemaVersion: Int
    let widgets: [PlacedWidget]
    static let defaults: [PlacedWidget] = [.statusExplanation, .powerFlow, .significantEnergy, .powerMode, .chartLevel]
        .map { PlacedWidget($0) }

    /// Eski (schemaVersion 1) biçim: yalnızca ham widget adlarından oluşan düz dizi.
    private struct LegacyPayload: Codable {
        let schemaVersion: Int
        let widgets: [String]
    }

    static func decode(_ data: Data, legacy: [PanelWidget]) -> (items: [PlacedWidget], notice: String?) {
        let legacyPlaced = legacy.map { PlacedWidget($0) }
        guard !data.isEmpty else { return (legacyPlaced, nil) }
        if let value = try? JSONDecoder().decode(Self.self, from: data), value.schemaVersion == 2 {
            var seen = Set<PanelWidget>()
            let items = value.widgets.filter { seen.insert($0.widget).inserted }
            return (items, items.count == value.widgets.count ? nil : "Tanımsız veya tekrarlanan kartlar gösterilmedi; diğer kartlar korundu.")
        }
        if let value = try? JSONDecoder().decode(LegacyPayload.self, from: data), value.schemaVersion == 1 {
            var seen = Set<PanelWidget>()
            let items = value.widgets.compactMap(PanelWidget.init(rawValue:))
                .filter { seen.insert($0).inserted }
                .map { PlacedWidget($0, size: .wide) }
            return (items, items.count == value.widgets.count ? nil : "Tanımsız veya tekrarlanan kartlar gösterilmedi; diğer kartlar korundu.")
        }
        return (legacyPlaced, "Kaydedilmiş düzen okunamadı; varsayılan düzen gösteriliyor. Kaydetmeden önce düzeni kontrol edin.")
    }

    static func encode(_ items: [PlacedWidget]) throws -> Data {
        try JSONEncoder().encode(Self(schemaVersion: 2, widgets: items))
    }

    static func move(_ source: PanelWidget, before target: PanelWidget, in items: [PlacedWidget]) -> [PlacedWidget] {
        guard source != target,
              items.contains(where: { $0.widget == source }),
              let targetIndex = items.firstIndex(where: { $0.widget == target }) else { return items }
        var result = items.filter { $0.widget != source }
        guard let sourceItem = items.first(where: { $0.widget == source }) else { return items }
        let insertIndex = result.firstIndex(where: { $0.widget == target }) ?? targetIndex
        result.insert(sourceItem, at: insertIndex)
        return result
    }

    /// Saf yerleşim hesaplayıcı: sıralı kart listesini satırlara böler (bkz. `WidgetRow`).
    static func rows(for items: [PlacedWidget]) -> [WidgetRow] {
        var rows: [WidgetRow] = []
        var index = 0
        while index < items.count {
            let item = items[index]
            if item.size == .square {
                if index + 1 < items.count, items[index + 1].size == .square {
                    rows.append(.squarePair(item, items[index + 1]))
                    index += 2
                } else {
                    rows.append(.squareSingle(item))
                    index += 1
                }
            } else {
                rows.append(.wide(item))
                index += 1
            }
        }
        return rows
    }
}
