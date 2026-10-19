import Foundation
import CoreGraphics

/// A single pose keeps the hands attached to the screen throughout a reversal.
struct BotGeometry {
    static let fullWidth: CGFloat = 260
    static let compactWidth: CGFloat = 54
    static let height: CGFloat = 178
    static let compactHeight: CGFloat = 126
    static let duration: Double = 0.44
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
    // One reversible timeline: emerge behind the small base, then pull it open.
    var reachProgress: CGFloat { Self.smoothStep(CGFloat(progress) / 0.25) }
    var pullProgress: CGFloat { Self.smoothStep((CGFloat(progress) - 0.25) / 0.75) }
    var handOpacity: Double { Double(reachProgress) }
    var thumbOpacity: Double { Double(Self.smoothStep((reachProgress - 0.55) / 0.45)) }
    var handControlsAvailable: Bool { reachProgress == 1 }
    var centerX: CGFloat { (left ? 27 + 103 * pullProgress : 233 - 103 * pullProgress) + originCorrection * (1 - pullProgress) }
    var bottomY: CGFloat { 175 + verticalCorrection * (1 - pullProgress) }
    var shellWidth: CGFloat { 42 + 174 * pullProgress }
    var shellHeight: CGFloat { 26 + 52 * pullProgress }
    var shellY: CGFloat { bottomY - shellHeight / 2 }
    var shellTop: CGFloat { bottomY - shellHeight }
    var ventOffset: CGFloat { Self.smoothStep(pullProgress / 0.12) * (shellHeight / 2 - 4) }
    var ventHeight: CGFloat { 9 - 6 * Self.smoothStep(pullProgress / 0.12) }
    var antennaY: CGFloat { shellTop - 34 }
    var screenWidth: CGFloat { shellWidth - 12 }
    var screenHeight: CGFloat { 12 + 48 * pullProgress }
    var screenY: CGFloat { shellY - 3 }
    var gloveScale: CGFloat { 0.28 + 0.04 * reachProgress + 0.42 * pullProgress }
    private var gripDistance: CGFloat { shellWidth / 2 + 1 + 2 * pullProgress - 6 * (1 - reachProgress) }
    private var gripY: CGFloat { screenY + 6 * (1 - reachProgress) }
    var leftGrip: CGPoint { CGPoint(x: centerX - gripDistance, y: gripY) }
    var rightGrip: CGPoint { CGPoint(x: centerX + gripDistance, y: gripY) }
    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

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
