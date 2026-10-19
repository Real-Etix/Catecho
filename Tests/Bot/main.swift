import Foundation

@main struct BotTests {
    static func main() {
        let visible = CGRect(x: -1440, y: -300, width: 1440, height: 900)
        for left in [true, false] {
            for x in [CGFloat(0), 0.5, 1] {
                let anchor = AntennaAnchor(x: x, y: 0.5).frame(visible: visible)
                for open in [false, true] {
                    let frame = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: open)
                    precondition(visible.contains(frame), "Bot must stay on the current screen")
                    let restored = BotGeometry.anchorFrame(window: frame, visible: visible, left: left)
                    precondition(BotGeometry.windowFrame(anchor: restored, visible: visible, left: left, expanded: open) == frame, "Dragging must preserve placement in both states")
                }
                let compact = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: false)
                let reserved = BotGeometry.windowFrame(anchor: anchor, visible: visible, left: left, expanded: true)
                let correction = BotGeometry.reservationOffset(anchor: anchor, visible: visible, left: left)
                let closedCenter = compact.minX + BotGeometry.compactWidth / 2
                let reservedCenter = reserved.minX + BotGeometry(progress: 0, left: left, originCorrection: correction).centerX
                precondition(abs(closedCenter - reservedCenter) < 0.01, "Reserving or releasing space must not teleport the body at either boundary")
            }
            let edge = AntennaAnchor(x: left ? 0 : 1, y: 1).frame(visible: visible)
            let closed = BotGeometry.windowFrame(anchor: edge, visible: visible, left: left, expanded: false)
            let open = BotGeometry.windowFrame(anchor: edge, visible: visible, left: left, expanded: true)
            precondition(left ? closed.minX == open.minX : closed.maxX == open.maxX, "Expansion grows toward the interior")
            precondition(closed.minY == open.minY)
            for step in 0...100 {
                let pose = BotGeometry(progress: Double(step) / 100, left: left)
                precondition(pose.screenWidth >= 96 && pose.screenWidth <= 256)
                precondition(pose.leftGrip.x == pose.centerX - pose.screenWidth / 2)
                precondition(pose.rightGrip.x == pose.centerX + pose.screenWidth / 2)
                precondition(pose.leftGrip.x >= 14 && pose.rightGrip.x <= BotGeometry.fullWidth - 14)
            }
        }
        for left in [true, false] {
            let correction: CGFloat = left ? 132 : -132
            let moved = CGRect(x: -900, y: -120, width: BotGeometry.fullWidth, height: BotGeometry.height)
            let saved = BotGeometry.anchorFrame(window: moved, visible: visible, left: left, reservedCorrection: correction)
            let released = BotGeometry.windowFrame(anchor: saved, visible: visible, left: left, expanded: false)
            let closingCenter = moved.minX + BotGeometry(progress: 0, left: left, originCorrection: correction).centerX
            precondition(abs(closingCenter - released.midX) < 0.01, "Dragging a corrected reserved window must keep the same body position when released")
        }
        precondition(BotGeometry(progress: -.infinity, left: false).progress == 0)
        precondition(BotGeometry(progress: 2, left: false).progress == 1)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 30, height: 2), hand: 1) == true)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: -30, height: 2), hand: -1) == true)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 30, height: 2), hand: -1) == false)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 1, height: 40), hand: 1) == nil)
        precondition(BotGeometry.dragTarget(translation: CGSize(width: 3, height: 1), hand: 1) == nil)
        print("PASS bot bounds, inward expansion, drag roundtrips on both edges, 202 connected grip poses and intentional pull gestures")
    }
}
