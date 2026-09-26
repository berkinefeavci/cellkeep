import Foundation

enum SettingsPage: String, CaseIterable, Identifiable {
    case dashboard, charge, sleep, energy, schedule, shortcuts, popover, menubar, general, magsafeLED, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Gösterge Tablosu"
        case .charge: return "Şarj Kontrolü"
        case .sleep: return "Uyku Davranışı"
        case .energy: return "Enerji Kullanımı"
        case .schedule: return "Takvim"
        case .shortcuts: return "Kısayollar"
        case .popover: return "Açılır Panel"
        case .menubar: return "Menü Çubuğu"
        case .general: return "Genel"
        case .magsafeLED: return "MagSafe Işığı"
        case .about: return "Hakkında"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .charge: return "bolt.fill"
        case .sleep: return "moon.fill"
        case .energy: return "chart.xyaxis.line"
        case .schedule: return "calendar"
        case .shortcuts: return "square.stack.3d.up.fill"
        case .popover: return "macwindow"
        case .menubar: return "menubar.rectangle"
        case .general: return "gearshape.fill"
        case .magsafeLED: return "light.beacon.max.fill"
        case .about: return "info.circle.fill"
        }
    }
}
