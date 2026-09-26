import Foundation

@main struct SettingsLayoutTests {
    static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            assertions += 1
            if !condition() {
                fputs("FAIL: \(message)\n", stderr)
                exit(1)
            }
        }

        check(SettingsLayout.contentMinWidth == 620, "minimum readable content width")
        check(SettingsLayout.contentMaxWidth == 760, "maximum scan width")
        check(SettingsLayout.windowMinWidth >= SettingsLayout.sidebarWidth + SettingsLayout.contentMinWidth
              + SettingsLayout.pageHorizontalPadding * 2,
              "window minimum contains sidebar, padding and readable content")
        check(SettingsLayout.windowMinWidth <= 860, "window can fit smaller displays")
        check(SettingsLayout.pageHorizontalPadding <= 20, "page edge padding stays compact")
        check(SettingsLayout.cardSpacing <= 14, "card stack stays compact")
        check(SettingsLayout.windowIdealWidth > SettingsLayout.windowMinWidth,
              "ideal width leaves room for the centered content column")
        print("Settings layout: \(assertions) assertions passed.")
    }
}
