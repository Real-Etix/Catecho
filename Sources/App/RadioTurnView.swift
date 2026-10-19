import SwiftUI
import QuartzCore

/// Both faces stay mounted so a tentative turn cannot throw away a settings draft.
struct RadioTurnStage<Front: View, Back: View>: View {
    let angle: Double
    let backShown: Bool
    let interacting: Bool
    let classic: Bool
    let reduceMotion: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    var body: some View {
        ZStack {
            if !reduceMotion { RadioCaseSidewall(angle: angle, classic: classic).allowsHitTesting(false) }
            front
                .modifier(RadioTurnFace(angle: reduceMotion ? (backShown ? 180 : 0) : angle, back: false, classic: classic))
                .allowsHitTesting(!backShown && !interacting)
                .accessibilityHidden(backShown || interacting)
            back
                .modifier(RadioTurnFace(angle: reduceMotion ? (backShown ? 180 : 0) : angle, back: true, classic: classic))
                .allowsHitTesting(backShown && !interacting)
                .accessibilityHidden(!backShown || interacting)
        }.frame(width: 350, height: 392)
    }
}

/// Visibility and lighting follow the interpolated angle, not its destination.
private struct RadioTurnFace: AnimatableModifier {
    @Environment(\.radioTurnLighting) private var parentTurning
    var angle: Double
    let back: Bool
    let classic: Bool
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View {
        let geometry = RadioCaseGeometry(angle: angle, classic: classic)
        let p = geometry.faceProjection(back: back)
        var matrix = CATransform3DIdentity
        matrix.m11 = p.a; matrix.m21 = 0; matrix.m41 = p.c
        matrix.m12 = p.d; matrix.m22 = p.e; matrix.m42 = p.f
        matrix.m14 = p.g; matrix.m24 = 0; matrix.m44 = p.i
        return content
            .environment(\.radioTurnLighting, max(parentTurning, abs(geometry.sine)))
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black.opacity(classic ? abs(geometry.sine) * 0.10 : 0))
                    .allowsHitTesting(false)
            }
            .projectionEffect(ProjectionTransform(matrix))
            .opacity(geometry.faceVisible(back: back) ? 1 : 0)
    }
}

/// Extrude the rounded case perimeter between the front and back planes.
/// Soft metallic edge lighting uses exactly the faces' projection.
private struct RadioCaseSidewall: View, Animatable {
    var angle: Double
    let classic: Bool
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    private static let perimeter: [CGPoint] = {
        let corners: [(Double, Double, Double)] = [(150, -171, -90), (150, 171, 0), (-150, 171, 90), (-150, -171, 180)]
        return corners.flatMap { x, y, start in
            (0...12).map { step in
                let theta = (start + Double(step) * 7.5) * .pi / 180
                return CGPoint(x: x + 25 * cos(theta), y: y + 25 * sin(theta))
            }
        }
    }()
    var body: some View {
        let geometry = RadioCaseGeometry(angle: angle, classic: classic)
        Canvas { context, _ in
            let points = Self.perimeter
            for index in points.indices {
                let a = points[index], b = points[(index + 1) % points.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let length = hypot(dx, dy)
                guard length > 0.001 else { continue }
                let nx = dy / length, ny = -dx / length
                let facing = -nx * geometry.sine
                guard facing > 0.0001 else { continue }
                let light = max(0, -0.35 * nx * geometry.cosine - 0.45 * ny + 0.65 * facing)
                let front = geometry.depth / 2, rear = -front
                if classic {
                    // Continuous satin aluminium roll: no raised rails or center plastic seam.
                    // A curved surface normal softens both edges without adding casing depth.
                    for band in 0..<32 {
                        let t0 = Double(band) / 32, t1 = Double(band + 1) / 32
                        let t = (t0 + t1) / 2
                        let u = 2 * t - 1
                        // Broad, low-contrast edge roll; a specular peak reads as a white stripe.
                        let edgeRoll = pow(abs(u), 6) * 0.025
                        let shade = 0.75 + 0.065 * light + 0.012 * u - edgeRoll
                        let metal = Color(red: shade + 0.050, green: shade + 0.029, blue: shade - 0.007)
                        let surface = strip(a, b, from: rear + geometry.depth * t0, to: rear + geometry.depth * t1, geometry: geometry)
                        context.fill(surface, with: .color(metal))
                        context.stroke(surface, with: .color(metal), lineWidth: 0.35)
                    }
                    context.stroke(line(a, b, z: front, geometry: geometry), with: .color(RadioPlastic.highlight.opacity(0.62)), lineWidth: 0.6)
                    context.stroke(line(a, b, z: rear, geometry: geometry), with: .color(RadioPlastic.edge.opacity(0.30)), lineWidth: 0.5)
                } else {
                    context.fill(strip(a, b, from: rear, to: front, geometry: geometry), with: .color(Color(red: 0.905, green: 0.888, blue: 0.845)))
                }
            }
        }
        .frame(width: 350, height: 392)
    }
    private func strip(_ a: CGPoint, _ b: CGPoint, from: Double, to: Double, geometry: RadioCaseGeometry) -> Path {
        let corners = [geometry.project(x: a.x, y: a.y, z: from), geometry.project(x: b.x, y: b.y, z: from),
                       geometry.project(x: b.x, y: b.y, z: to), geometry.project(x: a.x, y: a.y, z: to)]
        return Path { path in path.addLines(corners); path.closeSubpath() }
    }
    private func line(_ a: CGPoint, _ b: CGPoint, z: Double, geometry: RadioCaseGeometry) -> Path {
        Path { path in
            path.move(to: geometry.project(x: a.x, y: a.y, z: z))
            path.addLine(to: geometry.project(x: b.x, y: b.y, z: z))
        }
    }
}

/// Stationary hit areas live in the case margins, away from reading/scrolling controls.
struct RadioTurnGrip: View {
    let classic: Bool
    let label: String
    let hint: String
    let action: () -> Void
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ForEach(0..<6) { _ in
                    Capsule().fill(RadioPlastic.edge.opacity(hovering ? 0.85 : 0.55))
                        .frame(width: 5, height: 1)
                        .shadow(color: .white.opacity(classic ? 0.8 : 0), radius: 0, x: 0, y: 0.7)
                }
            }
            .frame(width: 16, height: 100).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .highPriorityGesture(DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { changed($0.translation) }
            .onEnded { ended($0.translation) })
        .onHover { hovering = $0 }
        .help(hint).accessibilityLabel(label).accessibilityHint(hint)
    }
}
