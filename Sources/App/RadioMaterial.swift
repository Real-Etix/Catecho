import SwiftUI

/// The front and settings cover are cast from the same warm plastic.
enum RadioPlastic {
    static let highlight = Color(red: 0.985, green: 0.977, blue: 0.95)
    static let edge = Color(red: 0.59, green: 0.57, blue: 0.52)
    static let recess = Color(red: 0.85, green: 0.835, blue: 0.79)
    static let sage = Color(red: 0.39, green: 0.43, blue: 0.37)
}

private struct RadioTurnLightingKey: EnvironmentKey {
    static let defaultValue = 0.0
}
extension EnvironmentValues {
    var radioTurnLighting: Double {
        get { self[RadioTurnLightingKey.self] }
        set { self[RadioTurnLightingKey.self] = newValue }
    }
}

struct RadioShell: View {
    let classic: Bool
    @Environment(\.radioTurnLighting) private var turning
    var body: some View {
        // Preserve the resting cover; tighten its 2D drop shadow before the side is visible.
        let turnFade = min(1, turning * 3)
        ZStack {
            if classic {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(red: 0.70, green: 0.68, blue: 0.63)).offset(y: 2 * (1 - turnFade))
                    .shadow(color: .black.opacity(0.25 - 0.09 * turnFade), radius: 5 - 3.5 * turnFade, x: 1 - turnFade, y: 5 - 4.2 * turnFade)
            }
            if classic {
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient(colors: [RadioPlastic.highlight, .radioCream, Color(red: 0.85, green: 0.83, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .shadow(.inner(color: .white.opacity(0.85), radius: 2.5, x: 1.5, y: 2))
                        .shadow(.inner(color: RadioPlastic.edge.opacity(0.4), radius: 3, x: -2, y: -3)))
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(RadioPlastic.edge.opacity(0.4), lineWidth: 0.6))
            } else {
                RoundedRectangle(cornerRadius: 25).fill(Color.radioCream)
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.radioInk, lineWidth: 1))
            }
        }
    }
}

/// A concentric cap, viewed square-on like the rest of the front cover.
struct RadioSettingsIcon: View {
    let classic: Bool
    var angle = 0.0
    var lifted = false
    var body: some View {
        ZStack {
            Circle().fill(classic ? RadioPlastic.edge : Color.radioCream)
                .overlay(Circle().stroke(RadioPlastic.highlight, lineWidth: 0.7))
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(classic ? 0.20 : 0), radius: 1.1, x: 0.5, y: 1.2)
            Circle().fill(LinearGradient(colors: [RadioPlastic.highlight, RadioPlastic.recess, RadioPlastic.edge], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
            if classic {
                ForEach(0..<24) { index in
                    Capsule().fill(RadioPlastic.edge.opacity(0.55)).frame(width: 0.6, height: 1.5)
                        .offset(y: -12).rotationEffect(.degrees(Double(index) * 15 + angle))
                }
            }
            Circle().fill(classic ? AnyShapeStyle(LinearGradient(colors: [RadioPlastic.highlight, .radioCream, RadioPlastic.recess], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream))
                .overlay(Circle().stroke(LinearGradient(colors: [.white.opacity(0.85), RadioPlastic.edge.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
                .frame(width: 22, height: 22)
            Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .medium))
                .foregroundStyle(RadioPlastic.sage)
                .shadow(color: .white.opacity(classic ? 0.7 : 0), radius: 0, x: 0, y: 0.6)
                .rotationEffect(.degrees(angle))
        }.frame(width: 30, height: 30).contentShape(Circle())
    }
}

struct RadioSettingsButton: View {
    let classic: Bool
    let label: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        Button {
            guard !turning else { return }
            if reduceMotion || !classic { action() }
            else { withAnimation(.easeInOut(duration: 0.24)) { turning = true } }
        } label: {
            RadioSettingsIcon(classic: classic, angle: turning ? -110 : 0, lifted: turning)
        }
        .buttonStyle(RadioHardwareButtonStyle())
        .help(label).accessibilityLabel(label)
        .task(id: turning) {
            guard turning else { return }
            do { try await Task.sleep(nanoseconds: 240_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            action()
            turning = false
        }
    }
}

/// Shallow relief in darker warm plastic: fine highlights, readable faces, no white lettering.
struct MoldedPlasticText: View {
    let text: String
    let size: CGFloat
    let classic: Bool
    var tracking: CGFloat = 1
    @Environment(\.colorSchemeContrast) private var contrast

    private var glyphs: Text {
        Text(text).font(.system(size: size, weight: .semibold).width(.condensed)).tracking(tracking)
    }
    var body: some View {
        ZStack {
            if classic {
                glyphs.foregroundStyle(Color(red: 0.33, green: 0.32, blue: 0.29).opacity(0.4)).offset(x: 0.4, y: 0.8).blur(radius: 0.3)
                glyphs.foregroundStyle(.white.opacity(0.6)).offset(x: -0.3, y: -0.4)
                glyphs.foregroundStyle(contrast == .increased ? AnyShapeStyle(Color.radioInk) : AnyShapeStyle(LinearGradient(colors: [Color(red: 0.405, green: 0.395, blue: 0.355), Color(red: 0.35, green: 0.34, blue: 0.30)], startPoint: .top, endPoint: .bottom)))
            } else { glyphs.foregroundStyle(Color.radioInk.opacity(0.85)) }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(text)
    }
}

