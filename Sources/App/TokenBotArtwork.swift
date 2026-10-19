import SwiftUI

enum BotMaterial {
    static let ivory = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let shade = Color(red: 0.69, green: 0.65, blue: 0.56)
    static let metal = LinearGradient(colors: [Color(white: 0.31), Color(white: 0.79), .white, Color(white: 0.48)], startPoint: .leading, endPoint: .trailing)
    static func cream(_ classic: Bool) -> AnyShapeStyle {
        classic ? AnyShapeStyle(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: ivory, location: 0.18), .init(color: .radioCream, location: 0.62), .init(color: shade, location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream)
    }
}

/// The original cream antenna base becomes the dashboard housing.
struct TokenBotShell: View {
    let classic: Bool
    let pose: BotGeometry
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9 + 5 * pose.progress, style: .continuous)
                .fill(classic ? AnyShapeStyle(LinearGradient(colors: [.white, .radioCream, Color(red: 0.79, green: 0.75, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream))
                .overlay(RoundedRectangle(cornerRadius: 9 + 5 * pose.progress).stroke(Color.radioInk.opacity(0.65), lineWidth: 0.8))
                .shadow(color: .black.opacity(classic ? 0.22 : 0), radius: 2, y: 2)
            if classic {
                RoundedRectangle(cornerRadius: 8 + 5 * pose.progress)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.85), .clear, BotMaterial.shade.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    .padding(1)
            }
            HStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Capsule().fill(Color.radioInk.opacity(0.45)).frame(width: 2, height: 3)
                        .shadow(color: .white.opacity(classic ? 0.7 : 0), radius: 0, y: 0.6)
                }
            }.offset(y: pose.shellHeight / 2 - 4)
        }.frame(width: pose.shellWidth, height: pose.shellHeight).accessibilityHidden(true)
    }
}

struct TokenBotArm: View {
    let pose: BotGeometry
    let hand: CGFloat
    let classic: Bool
    private var shoulder: CGPoint { CGPoint(x: pose.centerX + hand * 18, y: pose.shellTop + 4) }
    private var elbow: CGPoint { CGPoint(x: pose.centerX + hand * (22 + 93 * pose.progress), y: pose.shellTop + 3 - 13 * pose.progress) }
    private var wrist: CGPoint { hand < 0 ? pose.leftGrip : pose.rightGrip }
    var body: some View {
        ZStack {
            rod(from: shoulder, to: elbow, width: 1.5 + 2.5 * pose.progress)
            rod(from: elbow, to: wrist, width: 1 + 2 * pose.progress)
            joint(size: 3 + 5 * pose.progress).position(shoulder)
            joint(size: 3 + 4 * pose.progress).position(elbow)
        }.accessibilityHidden(true)
    }
    private func rod(from: CGPoint, to: CGPoint, width: CGFloat) -> some View {
        let length = hypot(to.x - from.x, to.y - from.y)
        return ZStack {
            Capsule().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioPaper))
                .overlay(Capsule().stroke(Color.radioInk.opacity(0.55), lineWidth: 0.6))
            Rectangle().fill(Color.radioInk.opacity(0.55)).frame(height: 1).offset(y: length * 0.15)
            Rectangle().fill(.white.opacity(classic ? 0.7 : 0)).frame(height: 1).offset(y: length * 0.15 + 1)
        }.frame(width: width, height: length)
            .rotationEffect(.radians(atan2(to.y - from.y, to.x - from.x) - .pi / 2))
            .position(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
    }
    private func joint(size: CGFloat) -> some View {
        Circle().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioCream))
            .overlay(Circle().stroke(Color.radioInk.opacity(0.45), lineWidth: 0.7))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(classic ? 0.16 : 0), radius: 1, y: 1)
    }
}

/// Four rounded fingers, a separate thumb and a cuff; no platform hand glyph.
struct TokenBotGlove: View {
    let classic: Bool
    let right: Bool
    private var white: AnyShapeStyle {
        classic ? AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.98), Color(red: 0.78, green: 0.77, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white)
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3).fill(white).frame(width: 9, height: 17).offset(x: 0, y: 13)
            RoundedRectangle(cornerRadius: 10).fill(white).frame(width: 21, height: 31).offset(x: 4, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.radioInk.opacity(0.18), lineWidth: 0.6).frame(width: 21, height: 31).offset(x: 4, y: 5))
            ForEach(0..<4) { finger in
                Capsule().fill(white).frame(width: 13, height: 7)
                    .overlay(Capsule().stroke(Color.radioInk.opacity(0.13), lineWidth: 0.5))
                    .offset(x: 15, y: 7 + CGFloat(finger) * 6.5)
            }
            Capsule().fill(white).frame(width: 11, height: 17)
                .overlay(Capsule().stroke(Color.radioInk.opacity(0.14), lineWidth: 0.6))
                .rotationEffect(.degrees(-30)).offset(x: 7, y: 0)
        }.frame(width: 29, height: 38)
            .scaleEffect(x: right ? -1 : 1, y: 1)
            .shadow(color: .black.opacity(classic ? 0.18 : 0), radius: 1.5, y: 1.5)
            .accessibilityHidden(true)
    }
}
