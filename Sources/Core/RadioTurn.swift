import Foundation

/// A deliberate horizontal pull turns the case; a short or vertical pull returns it.
enum RadioTurn {
    static func rotation(for translation: CGSize) -> Double {
        guard abs(translation.width) > abs(translation.height) * 1.25 else { return 0 }
        return Double(max(-180, min(180, translation.width)))
    }
    static func commits(_ translation: CGSize) -> Bool {
        abs(rotation(for: translation)) >= 80
    }
    static func destination(from restingAngle: Double, translation: CGSize, allowed: Bool) -> Double {
        guard allowed, commits(translation) else { return restingAngle }
        return restingAngle + (translation.width < 0 ? -180 : 180)
    }
    static func frontFacesViewer(_ angle: Double) -> Bool {
        cos(angle * .pi / 180) >= 0
    }
}
