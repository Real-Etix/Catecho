import Foundation
import CoreGraphics

/// A single pose keeps the hands attached to the screen throughout a reversal.
struct BotGeometry {
    static let fullWidth: CGFloat = 304
    static let compactWidth: CGFloat = 172
    static let height: CGFloat = 214
    static let duration: Double = 0.28
    let progress: Double
    let left: Bool
    let originCorrection: CGFloat

    init(progress: Double, left: Bool, originCorrection: CGFloat = 0) {
        self.progress = progress.isFinite ? min(1, max(0, progress)) : 0
        self.left = left
        self.originCorrection = originCorrection.isFinite ? originCorrection : 0
    }
    var centerX: CGFloat { (left ? 86 + 66 * progress : 218 - 66 * progress) + originCorrection * (1 - progress) }
    var screenWidth: CGFloat { 96 + 160 * progress }
    var screenY: CGFloat { 151 }
    var leftGrip: CGPoint { CGPoint(x: centerX - screenWidth / 2, y: screenY) }
    var rightGrip: CGPoint { CGPoint(x: centerX + screenWidth / 2, y: screenY) }

    static func windowFrame(anchor: CGRect, visible: CGRect, left: Bool, expanded: Bool) -> CGRect {
        let width = expanded ? fullWidth : compactWidth
        return bounded(CGRect(x: left ? anchor.minX : anchor.maxX - width, y: anchor.minY, width: width, height: height), visible: visible)
    }
    static func anchorFrame(window: CGRect, visible: CGRect, left: Bool, reservedCorrection: CGFloat = 0) -> CGRect {
        bounded(CGRect(x: (left ? window.minX : window.maxX - 54) + reservedCorrection, y: window.minY, width: 54, height: 126), visible: visible)
    }
    static func reservationOffset(anchor: CGRect, visible: CGRect, left: Bool) -> CGFloat {
        let compact = windowFrame(anchor: anchor, visible: visible, left: left, expanded: false)
        let reserved = windowFrame(anchor: anchor, visible: visible, left: left, expanded: true)
        return compact.minX - reserved.minX - (left ? 0 : fullWidth - compactWidth)
    }
    private static func bounded(_ frame: CGRect, visible: CGRect) -> CGRect {
        CGRect(x: min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width)),
               y: min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height)), width: frame.width, height: frame.height)
    }
    /// Positive `hand` denotes the right glove; vertical moves belong to the antenna/base.
    static func dragTarget(translation: CGSize, hand: CGFloat) -> Bool? {
        guard abs(translation.width) >= 18, abs(translation.width) > abs(translation.height) * 1.3 else { return nil }
        return translation.width * hand > 0
    }
}
