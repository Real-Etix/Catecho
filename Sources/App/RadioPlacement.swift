import AppKit

struct AntennaAnchor {
    let x: CGFloat
    let y: CGFloat

    init(x: CGFloat, y: CGFloat) {
        self.x = x.isFinite ? min(max(x, 0), 1) : 0.5
        self.y = y.isFinite ? min(max(y, 0), 1) : 0.5
    }
    init(frame: CGRect, visible: CGRect) {
        let clamped = RadioPlacement.clamp(frame, visible: visible)
        self.init(x: (clamped.minX - visible.minX) / max(1, visible.width - frame.width),
                  y: (clamped.minY - visible.minY) / max(1, visible.height - frame.height))
    }
    func frame(visible: CGRect) -> CGRect {
        RadioPlacement.clamp(CGRect(x: visible.minX + x * max(0, visible.width - 54),
                                    y: visible.minY + y * max(0, visible.height - 126),
                                    width: 54, height: 126), visible: visible)
    }
}

enum RadioPlacement {
    static func clamp(_ frame: CGRect, visible: CGRect) -> CGRect {
        CGRect(x: min(max(frame.minX, visible.minX), max(visible.minX, visible.maxX - frame.width)),
               y: min(max(frame.minY, visible.minY), max(visible.minY, visible.maxY - frame.height)),
               width: frame.width, height: frame.height)
    }
    static func expandedFrame(anchor: CGRect, visible: CGRect, left: Bool) -> CGRect {
        clamp(CGRect(x: left ? anchor.minX : anchor.maxX - 374, y: anchor.minY, width: 374, height: 416), visible: visible)
    }
    static func antennaFrame(expanded: CGRect, visible: CGRect, left: Bool) -> CGRect {
        clamp(CGRect(x: left ? expanded.minX : expanded.maxX - 54, y: expanded.minY, width: 54, height: 126), visible: visible)
    }
    static func screenIndex(frame: CGRect, screens: [CGRect]) -> Int? {
        if let index = screens.firstIndex(where: { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }) { return index }
        return screens.indices.max { a, b in
            let first = screens[a].intersection(frame), second = screens[b].intersection(frame)
            return (first.isNull ? 0 : first.width * first.height) < (second.isNull ? 0 : second.width * second.height)
        }
    }
}

struct EdgeGeometry {
    static func frame(visible: CGRect, expanded: Bool, left: Bool) -> CGRect {
        let anchor = AntennaAnchor(x: left ? 0 : 1, y: 0.5).frame(visible: visible)
        return expanded ? RadioPlacement.expandedFrame(anchor: anchor, visible: visible, left: left) : anchor
    }
}
