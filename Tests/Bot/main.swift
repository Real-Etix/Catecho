import Foundation
import CoreGraphics

@main struct BotTests {
    static func main() {
        let reaching = BotGeometry(progress: 0.2, left: false)
        precondition(reaching.shellWidth == 42 && reaching.shellHeight == 26,
                     "Hands must emerge before they pull the original base open")
        precondition(reaching.reachProgress > 0 && reaching.pullProgress == 0)
        for left in [true, false] {
            let hidden = BotGeometry(progress: 0, left: left)
            precondition(hidden.handOpacity == 0 && hidden.thumbOpacity == 0 && !hidden.handControlsAvailable,
                         "Resting hands, thumbs and their controls must be completely hidden")
            precondition(hidden.leftGrip.x - 14.5 * hidden.gloveScale > hidden.centerX - hidden.shellWidth / 2)
            precondition(hidden.rightGrip.x + 14.5 * hidden.gloveScale < hidden.centerX + hidden.shellWidth / 2,
                         "Hidden gloves start behind the base, not outside its edges")
            let ready = BotGeometry(progress: 0.3, left: left)
            precondition(ready.reachProgress == 1 && ready.pullProgress == 0 && ready.handControlsAvailable)
            precondition(ready.thumbOpacity == 1 && ready.shellWidth == hidden.shellWidth,
                         "The gloves grip the casing before it starts expanding")
            for progress in [0.32, 0.35, 0.38, 0.4] {
                let holding = BotGeometry(progress: progress, left: left)
                precondition(holding.leftGrip == ready.leftGrip && holding.rightGrip == ready.rightGrip,
                             "Hands must visibly hold their grip before pulling")
                precondition(holding.shellWidth == hidden.shellWidth && holding.shellHeight == hidden.shellHeight,
                             "The original base stays still during the grip pause")
            }
            let midpoint = BotGeometry(progress: 0.5, left: left)
            precondition(midpoint.reachProgress == 1 && midpoint.shellWidth > ready.shellWidth)
            // A reversal traverses the same poses; phase boundaries must not jump.
            for boundary in [0.0, 0.3, 0.4, 1.0] {
                let before = BotGeometry(progress: boundary - 0.00001, left: left)
                let after = BotGeometry(progress: boundary + 0.00001, left: left)
                precondition(abs(before.leftGrip.x - after.leftGrip.x) < 0.01)
                precondition(abs(before.shellWidth - after.shellWidth) < 0.01)
                precondition(abs(before.thumbOpacity - after.thumbOpacity) < 0.01)
            }
        }
        let visible = CGRect(x: -1440, y: -300, width: 1440, height: 900)
        for left in [true, false] {
            for x in [CGFloat(0), 0.5, 1] {
                for y in [CGFloat(0), 0.5, 1] {
                    let anchor = AntennaAnchor(x: x, y: y).frame(visible: visible)
                    let compact = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: false)
                    let reserved = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: true)
                    precondition(compact == anchor, "Resting widget must retain the original 54 × 126 antenna footprint")
                    precondition(reserved.size == CGSize(width: 260, height: 178))
                    precondition(visible.contains(compact) && visible.contains(reserved), "Both states must fit the selected display")
                    let offset = BotGeometry.reservationOffset(compact: compact, reserved: reserved, left: left)
                    let dx = offset.width, dy = offset.height
                    let pose = BotGeometry(progress: 0, left: left, originCorrection: dx, verticalCorrection: dy)
                    precondition(abs(compact.midX - (reserved.minX + pose.centerX)) < 0.01, "Reservation must preserve horizontal body position")
                    precondition(abs(compact.minY + 16 - (reserved.maxY - pose.shellY)) < 0.01, "Reservation must preserve vertical body position at the top edge")
                    let restored = BotGeometry.anchorFrame(window: reserved, visible: visible, left: left, reservedCorrection: dx, reservedVerticalCorrection: dy)
                    precondition(restored == anchor, "Releasing a reserved window must restore the original anchor on both axes")
                    for open in [false, true] {
                        let frame = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: open)
                        let saved = BotGeometry.anchorFrame(window: frame, visible: visible, left: left)
                        precondition(BotGeometry.windowFrame(anchor: saved, visible: visible, left: left, expanded: open) == frame, "Drag placement must round-trip in either state")
                    }
                    for step in 0...100 {
                        let intermediate = BotGeometry(progress: Double(step) / 100, left: left, originCorrection: dx, verticalCorrection: dy)
                        precondition(intermediate.leftGrip.x - 14.5 * intermediate.gloveScale >= 0)
                        precondition(intermediate.rightGrip.x + 14.5 * intermediate.gloveScale <= BotGeometry.fullWidth)
                        precondition(intermediate.antennaY - 59 >= 0 && intermediate.bottomY <= BotGeometry.height,
                                     "Antenna pull clearance and base must remain inside reserved bounds")
                    }
                }
            }
            let edge = AntennaAnchor(x: left ? 0 : 1, y: 0.5).frame(visible: visible)
            let closed = BotGeometry.windowFrame(anchor: edge, visible: visible, left: left, expanded: false)
            let open = BotGeometry.windowFrame(anchor: edge, visible: visible, left: left, expanded: true)
            precondition(left ? closed.minX == open.minX : closed.maxX == open.maxX, "Expansion grows toward the interior")
            precondition(closed.minY == open.minY)
            for step in 0...100 {
                let pose = BotGeometry(progress: Double(step) / 100, left: left)
                precondition(pose.shellWidth >= 42 && pose.shellWidth <= 216)
                precondition(pose.shellHeight >= 26 && pose.shellHeight <= 78)
                if pose.handControlsAvailable {
                    precondition(abs(pose.leftGrip.x - (pose.centerX - pose.shellWidth / 2 - 1 - 2 * pose.pullProgress)) < 0.01)
                    precondition(abs(pose.rightGrip.x - (pose.centerX + pose.shellWidth / 2 + 1 + 2 * pose.pullProgress)) < 0.01)
                    precondition(pose.leftGrip.y == pose.screenY && pose.rightGrip.y == pose.screenY)
                } else {
                    precondition(pose.shellWidth == 42 && pose.shellHeight == 26)
                }
            }
            let dx: CGFloat = left ? 206 : -206
            let dy: CGFloat = -52
            let moved = CGRect(x: -900, y: -120, width: BotGeometry.fullWidth, height: BotGeometry.height)
            let saved = BotGeometry.anchorFrame(window: moved, visible: visible, left: left, reservedCorrection: dx, reservedVerticalCorrection: dy)
            let released = BotGeometry.windowFrame(anchor: saved, visible: visible, left: left, expanded: false)
            let pose = BotGeometry(progress: 0, left: left, originCorrection: dx, verticalCorrection: dy)
            precondition(abs(moved.minX + pose.centerX - released.midX) < 0.01, "Moving a corrected reserved window must retain horizontal closing position")
            precondition(abs(moved.maxY - pose.shellY - (released.minY + 16)) < 0.01, "Moving a corrected reserved window must retain vertical closing position")
            precondition(BotGeometry.windowFrame(anchor: saved, visible: visible, left: left, expanded: true,
                                                reservedCorrection: CGSize(width: dx, height: dy)) == moved,
                         "Repositioning after a corrected drag must not move the open dashboard")
        }
        precondition(BotGeometry(progress: -.infinity, left: false).progress == 0)
        precondition(BotGeometry(progress: 2, left: false).progress == 1)
        precondition(BotGeometry(progress: 0, left: false, verticalCorrection: .nan).verticalCorrection == 0)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 30, height: 2), hand: 1) == true)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: -30, height: 2), hand: -1) == true)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 30, height: 2), hand: -1) == false)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 1, height: 40), hand: 1) == nil)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 3, height: 1), hand: 1) == nil)
        print("PASS hidden resting hands, reach-grip-pull sequence, stationary grip pause, reversible phase continuity, original antenna footprint, both-axis placement, 1818 bounded poses and connected grips")
    }
}
