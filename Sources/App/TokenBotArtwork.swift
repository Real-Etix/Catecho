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

/// A connected, curled hand: unequal knuckles, an opposed thumb and a top cuff.
/// Local coordinates stay inside the existing 29 × 38 grip envelope.
struct TokenBotGlove: View {
    let classic: Bool
    let right: Bool
    private var white: AnyShapeStyle {
        classic ? AnyShapeStyle(LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: Color(red: 0.98, green: 0.975, blue: 0.955), location: 0.48),
            .init(color: Color(red: 0.79, green: 0.78, blue: 0.73), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white)
    }
    private var seam: Color { Color(red: 0.48, green: 0.47, blue: 0.41).opacity(classic ? 0.48 : 0.6) }
    var body: some View {
        ZStack(alignment: .topLeading) {
            cuff.fill(white)
                .overlay(cuff.stroke(seam, lineWidth: 0.6))
            palm.fill(white)
                .overlay(palm.stroke(seam, style: StrokeStyle(lineWidth: 0.65, lineJoin: .round)))
            // Short creases divide curled fingers without outlining separate pills.
            fingerCreases.stroke(seam.opacity(0.8), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            thumb.fill(white)
                .shadow(color: .black.opacity(classic ? 0.13 : 0), radius: 0.6, x: 0.6, y: 0.8)
                .overlay(thumb.stroke(seam.opacity(0.8), style: StrokeStyle(lineWidth: 0.55, lineJoin: .round)))
            if classic {
                Path { p in
                    p.move(to: CGPoint(x: 6.4, y: 24.5))
                    p.addCurve(to: CGPoint(x: 10.5, y: 32.5), control1: CGPoint(x: 5.9, y: 28), control2: CGPoint(x: 7.5, y: 31.5))
                }.stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }.frame(width: 29, height: 38)
            .scaleEffect(x: right ? -1 : 1, y: 1)
            .shadow(color: .black.opacity(classic ? 0.18 : 0), radius: 1.2, x: right ? -0.5 : 0.5, y: 1.2)
            .accessibilityHidden(true)
    }
    private var cuff: Path {
        Path { p in
            p.move(to: CGPoint(x: 9.5, y: 1.5))
            p.addQuadCurve(to: CGPoint(x: 20.5, y: 1.5), control: CGPoint(x: 15, y: 0))
            p.addLine(to: CGPoint(x: 21, y: 8))
            p.addQuadCurve(to: CGPoint(x: 9, y: 8), control: CGPoint(x: 15, y: 10))
            p.closeSubpath()
        }
    }
    private var palm: Path {
        Path { p in
            p.move(to: CGPoint(x: 10, y: 7))
            p.addCurve(to: CGPoint(x: 21, y: 11.5), control1: CGPoint(x: 15, y: 7), control2: CGPoint(x: 19, y: 7.5))
            // Index, middle, ring and little finger form one tapered silhouette.
            p.addCurve(to: CGPoint(x: 26, y: 20), control1: CGPoint(x: 29, y: 11), control2: CGPoint(x: 29, y: 17.5))
            p.addCurve(to: CGPoint(x: 26, y: 26), control1: CGPoint(x: 29.5, y: 21), control2: CGPoint(x: 29, y: 24.5))
            p.addCurve(to: CGPoint(x: 23, y: 31.5), control1: CGPoint(x: 28, y: 28.5), control2: CGPoint(x: 26, y: 31))
            p.addCurve(to: CGPoint(x: 17, y: 36), control1: CGPoint(x: 24, y: 35), control2: CGPoint(x: 21, y: 36))
            p.addCurve(to: CGPoint(x: 5, y: 32), control1: CGPoint(x: 11, y: 37), control2: CGPoint(x: 7, y: 35.5))
            p.addCurve(to: CGPoint(x: 3, y: 21), control1: CGPoint(x: 2.5, y: 29), control2: CGPoint(x: 2, y: 24))
            p.addCurve(to: CGPoint(x: 10, y: 7), control1: CGPoint(x: 3.5, y: 15), control2: CGPoint(x: 8, y: 12))
            p.closeSubpath()
        }
    }
    private var fingerCreases: Path {
        Path { p in
            p.move(to: CGPoint(x: 16, y: 19))
            p.addCurve(to: CGPoint(x: 26, y: 20), control1: CGPoint(x: 20, y: 20.5), control2: CGPoint(x: 23, y: 21))
            p.move(to: CGPoint(x: 14.5, y: 24.5))
            p.addCurve(to: CGPoint(x: 26, y: 26), control1: CGPoint(x: 18, y: 26.5), control2: CGPoint(x: 22.5, y: 27))
            p.move(to: CGPoint(x: 13.5, y: 30))
            p.addCurve(to: CGPoint(x: 23, y: 31.5), control1: CGPoint(x: 16.5, y: 32), control2: CGPoint(x: 20, y: 33))
        }
    }
    private var thumb: Path {
        Path { p in
            p.move(to: CGPoint(x: 6, y: 23))
            p.addCurve(to: CGPoint(x: 7, y: 14), control1: CGPoint(x: 3.5, y: 20), control2: CGPoint(x: 4.5, y: 16))
            p.addCurve(to: CGPoint(x: 16.5, y: 10.5), control1: CGPoint(x: 10, y: 12), control2: CGPoint(x: 12.5, y: 9))
            p.addCurve(to: CGPoint(x: 18, y: 16), control1: CGPoint(x: 20, y: 11.5), control2: CGPoint(x: 20, y: 14))
            p.addCurve(to: CGPoint(x: 13, y: 21), control1: CGPoint(x: 16, y: 17.5), control2: CGPoint(x: 14.5, y: 18.5))
            p.addCurve(to: CGPoint(x: 6, y: 23), control1: CGPoint(x: 11.5, y: 24), control2: CGPoint(x: 8, y: 25))
            p.closeSubpath()
        }
    }
}
