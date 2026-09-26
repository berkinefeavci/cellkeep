import Foundation
import CoreGraphics

/// Panel genişlik modu.
///
/// Kalıcı tercih `UserDefaults` anahtarı: **"panelSizeMode"**
/// (değerler: "compact" | "normal" | "detailed"; varsayılan: "normal").
/// NOT: Ayarlar → Popover sayfasındaki seçici UI Views.swift tarafındadır ve
/// bu anahtarı okuyup yazmalıdır. PopoverView içeriği de dar/geniş düzen için
/// aynı anahtarı okuyabilir.
enum PanelSizeMode: String, CaseIterable, Identifiable {
    case compact
    case normal
    case detailed

    /// Views.swift sahibi ajana bildirilen kalıcı tercih anahtarı.
    static let storageKey = "panelSizeMode"

    /// Kullanıcı tercihi; okunamayan/bilinmeyen değerde Normal'e düşer.
    static var current: PanelSizeMode {
        PanelSizeMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .normal
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Kompakt"
        case .normal: return "Normal"
        case .detailed: return "Detaylı"
        }
    }

    /// Panel (ve içerik) genişliği.
    var width: CGFloat {
        switch self {
        case .compact: return 340
        case .normal: return 400
        case .detailed: return 520
        }
    }

    /// Popover içerik ölçümü SwiftUI'da ayrı bir görünüm ağacı gerektirir ve
    /// macOS 27 beta'da açılışta yeniden yerleşim döngüsü oluşturabilir.
    /// İçerik zaten kaydırılabildiği için mod başına kararlı bir yükseklik kullanılır.
    var preferredHeight: CGFloat {
        switch self {
        case .compact: return 430
        case .normal: return 640
        case .detailed: return 760
        }
    }
}

/// Panel geometrisi için saf, yan etkisiz hesaplayıcı.
/// AppKit/SwiftUI bağımlılığı yok; doğrulama scriptiyle tek başına derlenebilir.
enum PanelSizing {
    /// İçerik çok kısaysa bile panelin düşmeyeceği en küçük yükseklik.
    static let minHeight: CGFloat = 220
    /// Ekran üst/alt kenarından bırakılan nefes payı.
    static let verticalMargin: CGFloat = 8
    /// Ekran sol/sağ kenarından bırakılan nefes payı.
    static let horizontalMargin: CGFloat = 8
    /// Menü çubuğu çapası ile panel üstü arasındaki boşluk.
    static let anchorGap: CGFloat = 6

    /// Verilen ekran (visibleFrame) için izin verilen en büyük panel yüksekliği.
    static func maxHeight(for screen: CGRect) -> CGFloat {
        max(minHeight, screen.height - 2 * verticalMargin)
    }

    /// Panel boyutu: genişlik moddan; yükseklik içerikten gelir,
    /// [minHeight, ekran sınırı] aralığına kenetlenir — artan boşluk kalmaz.
    static func panelSize(for mode: PanelSizeMode, content: CGSize, screen: CGRect) -> CGSize {
        let fitted = content.height.isFinite ? content.height.rounded() : maxHeight(for: screen)
        let height = min(max(fitted, minHeight), maxHeight(for: screen))
        return CGSize(width: mode.width, height: height)
    }

    /// Panel kökeni: menü çubuğu çapasına hizalı, ekran sınırları içinde.
    static func panelOrigin(anchor: CGRect, size: CGSize, screen: CGRect) -> CGPoint {
        let x = min(max(anchor.midX - size.width / 2, screen.minX + horizontalMargin),
                    screen.maxX - horizontalMargin - size.width)
        let top = min(anchor.minY - anchorGap, screen.maxY - verticalMargin)
        let y = max(screen.minY + verticalMargin, top - size.height)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    static func panelFrame(anchor: CGRect, mode: PanelSizeMode, content: CGSize, screen: CGRect) -> CGRect {
        let size = panelSize(for: mode, content: content, screen: screen)
        return CGRect(origin: panelOrigin(anchor: anchor, size: size, screen: screen), size: size)
    }

    /// Doğrulama/log çıktısı için tek satırlık özet.
    static func debugDescription(mode: PanelSizeMode, content: CGSize, screen: CGRect, result: CGRect) -> String {
        String(format: "PanelSizing · mod=%@ genişlik=%.0f içerik=%.0fx%.0f ekran=%.0fx%.0f → panel=%.0fx%.0f @ (%.0f, %.0f)",
               mode.displayName, mode.width,
               content.width, content.height, screen.width, screen.height,
               result.width, result.height, result.minX, result.minY)
    }
}
