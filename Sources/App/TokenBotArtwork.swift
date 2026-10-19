import SwiftUI

enum BotMaterial {
    static let ivory = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let shade = Color(red: 0.69, green: 0.65, blue: 0.56)
    static let metal = LinearGradient(colors: [Color(white: 0.31), Color(white: 0.79), .white, Color(white: 0.48)], startPoint: .leading, endPoint: .trailing)
    static func cream(_ classic: Bool) -> AnyShapeStyle {
        classic ? AnyShapeStyle(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: ivory, location: 0.18), .init(color: .radioCream, location: 0.62), .init(color: shade, location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream)
    }
}

struct TokenBotShell: View {
    let classic: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(BotMaterial.cream(classic))
                .shadow(color: .black.opacity(classic ? 0.22 : 0), radius: 3, x: 0, y: 3)
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(classic ? 0.95 : 0), .radioInk.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .padding(1)
            if classic {
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .fill(Color.clear.shadow(.inner(color: BotMaterial.shade.opacity(0.55), radius: 7, x: -3, y: -4)))
                    .padding(2)
            }
            // The belly has a genuine recess behind the telescopic screen frame.
            RoundedRectangle(cornerRadius: 15).fill(Color.radioInk.opacity(0.38))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(classic ? 0.6 : 0), lineWidth: 1).offset(y: 1))
                .frame(width: 108, height: 79).offset(y: 20)
            face.offset(y: -34)
            VStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Capsule().fill(Color.radioInk.opacity(0.55)).frame(width: 20, height: 2)
                        .shadow(color: .white.opacity(classic ? 0.6 : 0), radius: 0, y: 1)
                }
            }.offset(y: 65)
            Path { p in p.move(to: CGPoint(x: 15, y: 139)); p.addQuadCurve(to: CGPoint(x: 111, y: 139), control: CGPoint(x: 63, y: 145)) }
                .stroke(BotMaterial.shade.opacity(0.7), lineWidth: 0.7)
        }.frame(width: 126, height: 152).accessibilityHidden(true)
    }
    private var face: some View {
        HStack(spacing: 17) {
            eye
            Path { p in p.move(to: CGPoint(x: 0, y: 2)); p.addQuadCurve(to: CGPoint(x: 12, y: 2), control: CGPoint(x: 6, y: 9)) }
                .stroke(Color.radioInk, style: StrokeStyle(lineWidth: 1.7, lineCap: .round)).frame(width: 12, height: 8).offset(y: 6)
            eye
        }
    }
    private var eye: some View {
        Capsule().fill(Color.radioInk).frame(width: 4.5, height: 9)
            .overlay(Capsule().stroke(.white.opacity(classic ? 0.6 : 0), lineWidth: 0.6).offset(y: 0.5))
    }
}

struct TokenBotAerial: View {
    let classic: Bool
    var lift: CGFloat = 0
    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioPaper))
                .frame(width: 5, height: 30 + lift).offset(y: -3)
            Capsule().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioCream))
                .frame(width: 7, height: 13).offset(y: -2)
            Circle().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioCream))
                .overlay(Circle().stroke(Color.radioInk.opacity(0.65), lineWidth: 0.6))
                .frame(width: 8, height: 8).offset(y: -30 - lift)
            Capsule().fill(Color.radioInk.opacity(0.65)).frame(width: 7, height: 1).offset(y: -15)
            Ellipse().fill(classic ? AnyShapeStyle(BotMaterial.metal) : AnyShapeStyle(Color.radioCream))
                .overlay(Ellipse().stroke(Color.radioInk.opacity(0.55), lineWidth: 0.7))
                .frame(width: 15, height: 5)
        }.frame(width: 32, height: 52, alignment: .bottom).accessibilityHidden(true)
    }
}

struct TokenBotArm: View {
    let centerX: CGFloat
    let progress: Double
    let hand: CGFloat
    let classic: Bool
    private var shoulder: CGPoint { CGPoint(x: centerX + hand * 62, y: 109) }
    private var elbow: CGPoint { CGPoint(x: centerX + hand * (74 + 60 * progress), y: 146 - 24 * progress) }
    private var wrist: CGPoint { CGPoint(x: centerX + hand * (52 + 80 * progress), y: 151) }
    var body: some View {
        ZStack {
            rod(from: shoulder, to: elbow, width: 5.5)
            rod(from: elbow, to: wrist, width: 4.5)
            joint(size: 13).position(shoulder)
            joint(size: 8).position(elbow)
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
