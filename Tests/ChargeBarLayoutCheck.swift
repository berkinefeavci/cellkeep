import Foundation
import CoreGraphics

@main struct ChargeBarLayoutCheck {
    static func main() {
        // No fill at all (percentage unavailable): falls back to the bar's own center.
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 0, textWidth: 20) == 170)

        // Fill wide enough to center the glyph within it (>= 110pt default threshold): centered
        // on the fill, not on the whole bar — this is the bug fix: previously a 50%-of-80% fill
        // (~170pt wide inside a 340pt bar) centered the glyph on the whole bar, landing near the
        // fill/track boundary instead of inside the fill.
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 170, textWidth: 20) == 85)
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 110, textWidth: 20) == 55)

        // Narrow fill (below threshold) but with room: placed just right of the percentage text,
        // inside the fill.
        let narrow = ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 80, textWidth: 20)
        precondition(narrow == 12 + 20 + 10) // textLeadingInset + textWidth + textTrailingGap

        // Narrow fill with no room for the glyph even next to the text: hidden (nil), never
        // straddling the fill/track edge.
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 34, textWidth: 20) == nil)
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 5, textWidth: 20) == nil)

        // Wider percentage text (e.g. "%100") pushes the "just right of text" placement further,
        // and can push a previously-fitting case into "hidden".
        let wideText = ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 80, textWidth: 40)
        precondition(wideText == 12 + 40 + 10)
        precondition(ChargeBarLayout.glyphCenterX(barWidth: 340, fillWidth: 60, textWidth: 40) == nil)

        print("PASS: charge bar status glyph centers within the fill, sits beside the text, or hides — never straddles the fill/track edge")
    }
}
