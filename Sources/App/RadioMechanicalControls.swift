import SwiftUI

/// All binary settings share one physical slider; the native Toggle supplies its label/state.
struct RadioSlideSwitchStyle: ToggleStyle {
    let classic: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 2)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(RadioPlastic.recess.shadow(.inner(color: .black.opacity(classic ? 0.28 : 0), radius: 1.5, x: 0, y: 1.5)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(RadioPlastic.edge.opacity(0.55), lineWidth: 0.6))
                    HStack {
                        Capsule().fill(RadioPlastic.sage).frame(width: 6, height: 2)
                        Spacer()
                        Circle().stroke(RadioPlastic.edge.opacity(0.8), lineWidth: 0.8).frame(width: 4, height: 4)
                    }.padding(.horizontal, 6)
                    RadioSliderThumb(classic: classic).frame(width: 19, height: 16).padding(2)
                }.frame(width: 42, height: 20)
            }.contentShape(Rectangle())
        }
        .buttonStyle(RadioHardwareButtonStyle())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isOn)
        .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
    }
}

struct RadioSliderThumb: View {
    let classic: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(classic ? AnyShapeStyle(LinearGradient(colors: [RadioPlastic.highlight, .radioCream, RadioPlastic.recess], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.radioCream))
            .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(RadioPlastic.edge.opacity(0.6), lineWidth: 0.5))
            .overlay(HStack(spacing: 2.5) {
                ForEach(0..<3) { _ in
                    Capsule().fill(RadioPlastic.edge.opacity(0.65)).frame(width: 0.7, height: 7)
                        .shadow(color: .white.opacity(classic ? 0.75 : 0), radius: 0, x: 0.7, y: 0)
                }
            })
            .shadow(color: .black.opacity(classic ? 0.25 : 0), radius: 1, x: 0.5, y: 1.3)
    }
}

/// Labels sit on the housing above a single detent rail, rather than system segments/popups.
struct RadioDetentPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]
    let classic: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .medium))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button { selection = option.0 } label: {
                        VStack(spacing: 4) {
                            Text(option.1).font(.system(size: 10, weight: selection == option.0 ? .semibold : .regular))
                                .multilineTextAlignment(.center).lineLimit(2).frame(maxWidth: .infinity, minHeight: 25)
                                .foregroundStyle(selection == option.0 ? Color.radioInk : Color.radioInk.opacity(0.7))
                            ZStack {
                                Circle().fill(RadioPlastic.edge.opacity(0.8)).frame(width: 3, height: 3)
                                if selection == option.0 { RadioSliderThumb(classic: classic).frame(width: 30, height: 14) }
                            }.frame(maxWidth: .infinity).frame(height: 18)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title + ": " + option.1)
                    .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
                }
            }
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(RadioPlastic.recess.shadow(.inner(color: .black.opacity(classic ? 0.22 : 0), radius: 1.2, x: 0, y: 1.5)))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(RadioPlastic.edge.opacity(0.5), lineWidth: 0.6))
                    .frame(height: 18)
            }
        }.accessibilityElement(children: .contain)
    }
}

/// An explicit turn action, not a latch pretending to close the whole radio.
struct RadioFlipButton: View {
    let classic: Bool
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.radioInk.opacity(0.85))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(RadioPlastic.sage)
                    .frame(width: 30, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [RadioPlastic.highlight, .radioCream, RadioPlastic.recess], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(RadioPlastic.edge.opacity(0.55), lineWidth: 0.6))
                    .shadow(color: .black.opacity(classic ? 0.16 : 0), radius: 1, x: 0, y: 1)
            }.padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(RadioHardwareButtonStyle())
    }
}

struct RadioServiceButtonStyle: ButtonStyle {
    let classic: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.radioInk).padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 4).fill((configuration.isPressed ? RadioPlastic.recess : Color.radioCream)
                .shadow(.inner(color: RadioPlastic.edge.opacity(classic ? 0.3 : 0), radius: 1, x: 0, y: 1))))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RadioPlastic.edge.opacity(0.5), lineWidth: 0.6))
    }
}

struct RadioFieldStyle: TextFieldStyle {
    let classic: Bool
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.padding(6).background(Color.radioCream, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(RadioPlastic.edge.opacity(0.6), lineWidth: 0.6))
    }
}
