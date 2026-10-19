import AppKit

@main
struct PlacementTests {
    static func main() {
        let visible = CGRect(x: -1440, y: -300, width: 1440, height: 900)
        precondition(EdgeGeometry.frame(visible: visible, expanded: false, left: false).size == CGSize(width: 54, height: 126), "Antenna must be 54 × 126")
        let tab = CGRect(x: -1050, y: -120, width: 54, height: 126)
        let saved = AntennaAnchor(frame: tab, visible: visible)
        precondition(saved.frame(visible: visible) == tab, "Normalized placement must roundtrip")
        let changed = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        precondition(changed.contains(saved.frame(visible: changed)), "Restore on changed display must remain visible")
        let opened = RadioPlacement.expandedFrame(anchor: tab, visible: visible, left: false)
        precondition(opened.minY == tab.minY && opened.maxX == tab.maxX, "Radio opens upward and toward screen interior")
        precondition(opened.size == CGSize(width: 374, height: 416))
        precondition(saved.frame(visible: visible) == tab, "Opening must preserve original antenna anchor")
        let far = CGRect(x: -3000, y: 5000, width: 54, height: 126)
        precondition(RadioPlacement.clamp(far, visible: visible) == CGRect(x: -1440, y: 474, width: 54, height: 126))
        let dragged = CGRect(x: -900, y: -150, width: 374, height: 416)
        let tuck = RadioPlacement.antennaFrame(expanded: dragged, visible: visible, left: false)
        precondition(tuck.minY == dragged.minY && tuck.maxX == dragged.maxX)
        let other = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        precondition(RadioPlacement.screenIndex(frame: dragged, screens: [other, visible]) == 1)
        let crossing = CGRect(x: -100, y: 0, width: 374, height: 416)
        precondition(RadioPlacement.screenIndex(frame: crossing, screens: [visible, other]) == 1)
        let invalid = AntennaAnchor(x: .nan, y: .infinity)
        precondition(visible.contains(invalid.frame(visible: visible)), "Corrupt stored positions must be safe")
        for left in [false, true] {
            let compact = RadioPlacement.tuckedFrame(anchor: tab, visible: visible, left: left, preview: true)
            precondition(compact.size == CGSize(width: 190, height: 126) && visible.contains(compact))
            precondition(RadioPlacement.antennaFrame(tucked: compact, visible: visible, left: left, preview: true) == tab)
            let boundary = AntennaAnchor(x: left ? 0 : 1, y: 1).frame(visible: visible)
            let onEdge = RadioPlacement.tuckedFrame(anchor: boundary, visible: visible, left: left, preview: true)
            precondition(visible.contains(onEdge) && RadioPlacement.antennaFrame(tucked: onEdge, visible: visible, left: left, preview: true) == boundary)
            precondition(RadioPlacement.tuckedFrame(anchor: tab, visible: visible, left: left, preview: false) == tab)
        }
        print("PASS compact Codex preview preserves antenna anchors, bounds and inverse drag mapping on both edges")
        print("PASS antenna size, normalized restore, upward expansion, tuck roundtrip, negative coordinates, clamp, monitor selection")
    }
}
