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
                    Capsule().fill(Color.radioInk.opacity(0.45)).frame(width: 2, height: 9 - 6 * pose.progress)
                        .shadow(color: .white.opacity(classic ? 0.7 : 0), radius: 0, y: 0.6)
                }
            }.offset(y: CGFloat(pose.progress) * (pose.shellHeight / 2 - 4))
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

enum TokenGloveLayer { case whole, rear, grip }

/// A soft mitten sits behind the case; only its thumb crosses the front edge.
/// Separating the layers makes it hold the screen instead of float on top of it.
struct TokenBotGlove: View {
    let classic: Bool
    let right: Bool
    var layer: TokenGloveLayer = .whole
    private var white: AnyShapeStyle {
        classic ? AnyShapeStyle(LinearGradient(colors: [.white, Color(red: 0.96, green: 0.95, blue: 0.92), Color(red: 0.81, green: 0.80, blue: 0.75)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white)
    }
    private var edge: Color { Color.radioInk.opacity(classic ? 0.23 : 0.35) }
    var body: some View {
        ZStack(alignment: .topLeading) {
            if layer != .grip {
                RoundedRectangle(cornerRadius: 2).fill(white)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(edge, lineWidth: 0.5))
                    .frame(width: 10, height: 6).offset(x: 10, y: 4)
                mitten.fill(white)
                    .overlay(mitten.stroke(edge, style: StrokeStyle(lineWidth: 0.55, lineJoin: .round)))
                    .shadow(color: .black.opacity(classic ? 0.13 : 0), radius: 1, x: -0.5, y: 1)
            }
            if layer != .rear {
                thumb.fill(white)
                    .overlay(thumb.stroke(edge, style: StrokeStyle(lineWidth: 0.5, lineJoin: .round)))
                    .shadow(color: .black.opacity(classic ? 0.16 : 0), radius: 0.8, x: 0.5, y: 1)
            }
        }.frame(width: 29, height: 38)
            .scaleEffect(x: right ? -1 : 1, y: 1)
            .accessibilityHidden(true)
    }
    private var mitten: Path {
        Path { p in
            p.move(to: CGPoint(x: 11, y: 9))
            p.addCurve(to: CGPoint(x: 22, y: 12), control1: CGPoint(x: 15, y: 8), control2: CGPoint(x: 20, y: 9))
            p.addCurve(to: CGPoint(x: 23, y: 26), control1: CGPoint(x: 25, y: 16), control2: CGPoint(x: 25, y: 22))
            p.addCurve(to: CGPoint(x: 15, y: 34), control1: CGPoint(x: 22, y: 32), control2: CGPoint(x: 19, y: 34))
            p.addCurve(to: CGPoint(x: 5, y: 28), control1: CGPoint(x: 10, y: 35), control2: CGPoint(x: 6, y: 33))
            p.addCurve(to: CGPoint(x: 6, y: 16), control1: CGPoint(x: 3.5, y: 24), control2: CGPoint(x: 4, y: 19))
            p.addCurve(to: CGPoint(x: 11, y: 9), control1: CGPoint(x: 7, y: 13), control2: CGPoint(x: 9, y: 11))
            p.closeSubpath()
        }
    }
    private var thumb: Path {
        Path { p in
            p.move(to: CGPoint(x: 16, y: 15))
            p.addCurve(to: CGPoint(x: 25, y: 15.5), control1: CGPoint(x: 19, y: 13), control2: CGPoint(x: 23, y: 13))
            p.addCurve(to: CGPoint(x: 25.5, y: 22), control1: CGPoint(x: 28, y: 17), control2: CGPoint(x: 28, y: 20.5))
            p.addCurve(to: CGPoint(x: 18, y: 21), control1: CGPoint(x: 23, y: 24), control2: CGPoint(x: 20, y: 23))
            p.addQuadCurve(to: CGPoint(x: 16, y: 15), control: CGPoint(x: 15, y: 19))
            p.closeSubpath()
        }
    }
}
