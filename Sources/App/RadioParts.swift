import SwiftUI

extension Color {
    static let radioInk = Color(red: 0.16, green: 0.19, blue: 0.17)
    static let radioPaper = Color(red: 0.79, green: 0.81, blue: 0.73)
    static let radioCream = Color(red: 0.93, green: 0.91, blue: 0.86)
}

struct WaveSignal: View {
    var active: Bool
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || reduceMotion)) { context in
            let phase = active && !reduceMotion ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4 : 0.45
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.76)
                let scale = min(size.width / 100, size.height / 70)
                for ring in 0..<3 {
                    let radius = CGFloat(14 + ring * 13) * scale
                    var path = Path()
                    path.addArc(center: center, radius: radius, startAngle: .degrees(212), endAngle: .degrees(328), clockwise: false)
                    let intensity = reduceMotion || !active ? 0.55 : 0.22 + 0.65 * max(0, cos((phase - Double(ring) * 0.18) * .pi * 2))
                    canvas.stroke(path, with: .color(.radioInk.opacity(intensity)), style: StrokeStyle(lineWidth: compact ? 1.5 : 2.4, lineCap: .round))
                }
                canvas.fill(Path(ellipseIn: CGRect(x: center.x - 3 * scale, y: center.y - 3 * scale, width: 6 * scale, height: 6 * scale)), with: .color(.radioInk))
            }
        }
        .accessibilityHidden(true)
    }
}

struct TuningDial: View {
    let classic: Bool
    let active: Bool
    let channelIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !active || reduceMotion)) { context in
            let angle = active && !reduceMotion ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) * 72 : Double(channelIndex * 65 + 35)
            ZStack {
                Circle().fill(classic ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.8), .radioCream, Color(red: 0.74, green: 0.70, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream))
                Circle().stroke(Color.radioInk.opacity(0.75), lineWidth: 1)
                Circle().inset(by: 3).stroke(Color.radioInk.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                Capsule().fill(Color.radioInk).frame(width: 2, height: 16).offset(y: -15).rotationEffect(.degrees(angle))
            }
            .frame(width: 61, height: 61)
            .shadow(color: .black.opacity(classic ? 0.22 : 0), radius: 3, x: 1, y: 3)
        }
        .accessibilityHidden(true)
    }
}

struct SpeakerGrille: View {
    let classic: Bool
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<8) { _ in
                Capsule().fill(Color.radioInk).frame(width: 75, height: 3)
                    .shadow(color: .white.opacity(classic ? 0.7 : 0), radius: 0, x: 0, y: 1)
            }
        }.accessibilityHidden(true)
    }
}

struct RadioRoundButton: View {
    let icon: String
    let label: String
    let classic: Bool
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium))
                .frame(width: 35, height: 35)
                .background(classic ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.7), .radioCream], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream), in: Circle())
                .overlay(Circle().stroke(Color.radioInk.opacity(0.7), lineWidth: 0.8))
                .shadow(color: .black.opacity(classic ? 0.14 : 0), radius: 2, x: 0, y: 2)
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(label).help(label)
    }
}
