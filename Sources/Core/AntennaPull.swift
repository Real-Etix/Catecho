import Foundation

enum AntennaPull {
    static let distance: CGFloat = 34
    static func opensRadio(_ translation: CGSize) -> Bool {
        translation.height <= -distance && abs(translation.width) < -translation.height * 0.75
    }
}
