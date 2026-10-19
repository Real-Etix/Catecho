import Foundation
import CoreGraphics

@main struct BotTests {
    static func main() {
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
                precondition(pose.leftGrip.x == pose.centerX - pose.shellWidth / 2 - 1 - 2 * pose.progress)
                precondition(pose.rightGrip.x == pose.centerX + pose.shellWidth / 2 + 1 + 2 * pose.progress)
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
        print("PASS original antenna footprint, both-axis reservation and drag continuity at every boundary, 1818 bounded poses, connected grips and intentional pulls")
    }
}
