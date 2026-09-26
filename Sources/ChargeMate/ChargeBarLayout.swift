import CoreGraphics

/// Pure placement logic for the charge bar's status glyph (`ChargeLimitBar` in Views.swift).
/// Kept dependency-free (no SwiftUI) so it's directly unit-testable.
enum ChargeBarLayout {
    /// Where the status glyph should be centered inside the bar, or nil to hide it entirely.
    ///
    /// The glyph used to be centered across the whole bar width, which put it right on the
    /// fill/track boundary whenever the fill didn't reach roughly the middle of the bar (e.g. a
    /// 50% charge against an 80% limit). Instead:
    /// - once the fill is wide enough to hold a centered icon without crowding the leading
    ///   percentage text (`centeredThreshold`), the glyph is centered within the fill;
    /// - otherwise it's placed just to the right of that text, still inside the fill;
    /// - if even that doesn't fit, it's hidden rather than straddling the fill/track edge.
    ///
    /// When there's no fill at all (`fillWidth <= 0`, e.g. percentage unavailable), the glyph
    /// falls back to the bar's own center, matching the prior "no fill" appearance.
    static func glyphCenterX(barWidth: CGFloat, fillWidth: CGFloat, textWidth: CGFloat,
                              centeredThreshold: CGFloat = 110, glyphHalfWidth: CGFloat = 7,
                              textLeadingInset: CGFloat = 12, textTrailingGap: CGFloat = 10,
                              edgeMargin: CGFloat = 6) -> CGFloat? {
        guard fillWidth > 0 else { return barWidth / 2 }
        if fillWidth >= centeredThreshold { return fillWidth / 2 }
        let afterText = textLeadingInset + textWidth + textTrailingGap
        guard afterText + glyphHalfWidth <= fillWidth - edgeMargin else { return nil }
        return afterText
    }
}
