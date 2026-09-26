# Menü Çubuğu İkonları

20 Eylül 2026 /0.3.9: `MenubarRenderer` artık bu varlıkları gerçek menü ve ortak önizlemede kullanır. `chargeStatus` bold, `macNative` native, `macColored` colored ailesine bağlanır. Logo/iOS ile nötr adaptör/veri-yok durumları çalışma anında çizilir. `paused`/`limited` fiziksel kontrol kanıtı olmadan seçilmez. Eski bold PNG'lerde transparent source-over durum işaretini kesmediği için renderer destination-out uygular; katalog hash'leri korunur.15 asset'in gerçek bundle'dan okunması ve altı stil×beş durum offscreen testi vardır; canlı UI kabulü ayrıca gereklidir.

Bu klasördeki set, ChargeMate menü çubuğu için 5 durum ve 3 görsel stilden oluşur. İkonlar `Tools/make-menubar-icons.sh` ile CoreGraphics kullanılarak programatik olarak üretilir. Script her çalıştırıldığında `Assets.xcassets/Menubar` klasörünü baştan oluşturur; `AppIcon.appiconset` değişmez.

## Varlık adları

Swift tarafında kullanılacak asset adları aşağıdaki gibidir. PNG dosyalarının 1x ve 2x sürümleri aynı imageset içindedir.

| Durum | native (template) | bold (template) | colored |
| --- | --- | --- | --- |
| Şarj oluyor | `charging-native` | `charging-bold` | `charging-colored` |
| Limitte durdu | `paused-native` | `paused-bold` | `paused-colored` |
| Fişte deşarj | `discharging-native` | `discharging-bold` | `discharging-colored` |
| Pilde çalışıyor | `unplugged-native` | `unplugged-bold` | `unplugged-colored` |
| Limitin altında şarj oluyor | `limited-native` | `limited-bold` | `limited-colored` |

Dosya biçimi `menubar_<durum>_<stil>.png` ve `menubar_<durum>_<stil>@2x.png` şeklindedir. Her dosya 24x16 pt ikon için sırasıyla 24x16 ve 48x32 piksel boyutundadır.

## Stil ve kullanım

- `native`: ince, siyah alfa çizgiler. Sistem menü çubuğu görünümüne yakındır ve template olarak işaretlidir.
- `bold`: daha kalın, dolu siyah gövde ve alfa ile açılmış durum işareti. Template olarak işaretlidir.
- `colored`: aynı geometriyi kullanır; şarj için yeşil, duraklatma için mavi, deşarj için turuncu, pilde çalışma için gri renktedir. Template değildir.

Durum seçimi için `charging`, `paused`, `discharging`, `unplugged` veya `limited` adını; görünüm tercihi için `native`, `bold` veya `colored` son ekini kullanın. `paused`, koruma limiti nedeniyle şarjın durduğu durumu; `limited`, limitin altında olup henüz şarj olan durumu ifade eder.

## Swift wiring örneği

```swift
let image = NSImage(named: "charging-native")
image?.isTemplate = true // native ve bold için; colored için false bırakın.
statusItem.button?.image = image
```

Asset kataloğu 1x/2x seçimini otomatik yapar. Üretim wiring'i yukarıdaki0.3.9 güncellemesinde tamamlanmıştır.

## Yeniden üretim

Proje kökünden çalıştırın:

```sh
Tools/make-menubar-icons.sh
```

Script macOS Swift/CoreGraphics ve ImageIO kullanır; hazır sistem ikonu veya SF Symbol kullanmaz.
