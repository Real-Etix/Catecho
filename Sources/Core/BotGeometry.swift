import Foundation
import CoreGraphics

/// A single pose keeps the hands attached to the screen throughout a reversal.
struct BotGeometry {
    static let fullWidth: CGFloat = 260
    static let compactWidth: CGFloat = 54
    static let height: CGFloat = 178
    static let compactHeight: CGFloat = 126
    static let duration: Double = 0.28
    let progress: Double
    let left: Bool
    let originCorrection: CGFloat
    let verticalCorrection: CGFloat

    init(progress: Double, left: Bool, originCorrection: CGFloat = 0, verticalCorrection: CGFloat = 0) {
        self.progress = progress.isFinite ? min(1, max(0, progress)) : 0
        self.left = left
        self.originCorrection = originCorrection.isFinite ? originCorrection : 0
        self.verticalCorrection = verticalCorrection.isFinite ? verticalCorrection : 0
    }
    var centerX: CGFloat { (left ? 27 + 103 * progress : 233 - 103 * progress) + originCorrection * (1 - progress) }
    var bottomY: CGFloat { 175 + verticalCorrection * (1 - progress) }
    var shellWidth: CGFloat { 42 + 174 * progress }
    var shellHeight: CGFloat { 26 + 52 * progress }
    var shellY: CGFloat { bottomY - shellHeight / 2 }
    var shellTop: CGFloat { bottomY - shellHeight }
    var antennaY: CGFloat { shellTop - 34 }
    var screenWidth: CGFloat { shellWidth - 12 }
    var screenHeight: CGFloat { 12 + 48 * progress }
    var screenY: CGFloat { shellY - 3 }
    var gloveScale: CGFloat { 0.28 + 0.46 * progress }
    var leftGrip: CGPoint { CGPoint(x: centerX - shellWidth / 2 - 1 - 2 * progress, y: screenY) }
    var rightGrip: CGPoint { CGPoint(x: centerX + shellWidth / 2 + 1 + 2 * progress, y: screenY) }

    static func windowFrame(anchor: CGRect, visible: CGRect, left: Bool, expanded: Bool, reservedCorrection: CGSize = .zero) -> CGRect {
        let width = expanded ? fullWidth : compactWidth
        let correction = expanded ? reservedCorrection : .zero
        return bounded(CGRect(x: (left ? anchor.minX : anchor.maxX - width) - correction.width,
                              y: anchor.minY + correction.height, width: width, height: expanded ? height : compactHeight), visible: visible)
    }
    static func anchorFrame(window: CGRect, visible: CGRect, left: Bool, reservedCorrection: CGFloat = 0, reservedVerticalCorrection: CGFloat = 0) -> CGRect {
        bounded(CGRect(x: (left ? window.minX : window.maxX - compactWidth) + reservedCorrection, y: window.minY - reservedVerticalCorrection, width: compactWidth, height: compactHeight), visible: visible)
    }
    static func reservationOffset(compact: CGRect, reserved: CGRect, left: Bool) -> CGSize {
        // AppKit origins grow upward; SwiftUI artwork grows downward.
        CGSize(width: compact.minX - reserved.minX - (left ? 0 : fullWidth - compactWidth),
               height: reserved.minY - compact.minY)
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
