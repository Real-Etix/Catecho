import SwiftUI
import QuartzCore

struct RadioPlasticGrain: View {
    var body: some View {
        Canvas { context, size in
            // Fixed, subtle mold grain, with no animation or random redraw noise.
            for index in 0..<900 {
                let x = CGFloat((index * 97 + 31) % 997) / 997 * size.width
                let y = CGFloat((index * 73 + 19) % 991) / 991 * size.height
                let mark = Path(ellipseIn: CGRect(x: x, y: y, width: 0.65, height: 0.5))
                context.fill(mark, with: .color(index.isMultiple(of: 2) ? .white.opacity(0.12) : RadioPlastic.edge.opacity(0.08)))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// A molded rear case with a visible sidewall, perimeter seam, and rounded lip.
struct RadioRearHousing: View {
    let classic: Bool
    var body: some View {
        RadioShell(classic: classic)
            .overlay { if classic { RadioPlasticGrain().clipShape(RoundedRectangle(cornerRadius: 25)) } }
            .overlay(RoundedRectangle(cornerRadius: 20).inset(by: 5).stroke(classic ? RadioPlastic.edge.opacity(0.18) : .clear, lineWidth: 0.6))
    }
}

struct RadioControlRecess: View {
    let classic: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(red: 0.895, green: 0.88, blue: 0.835)
                .shadow(.inner(color: Color.black.opacity(classic ? 0.17 : 0), radius: 3, x: 0.5, y: 2)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LinearGradient(colors: [RadioPlastic.edge.opacity(0.5), RadioPlastic.highlight.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
    }
}

/// The battery bay doubles as the radio's reception service compartment.
struct RadioBatteryCompartment: View {
    @ObservedObject var model: RadioModel
    @Binding var isOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var classic: Bool { model.isClassic }
    private var language: RadioLanguage { model.language }

    var body: some View {
        VStack(spacing: 0) {
            // Room for the lid to swing toward the viewer and above its fixed top hinge.
            Color.clear.frame(height: isOpen ? 44 : 0)
            RoundedRectangle(cornerRadius: 8)
                    .fill(RadioPlastic.recess.shadow(.inner(color: .black.opacity(classic ? 0.32 : 0), radius: 4, x: 0, y: 3)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(RadioPlastic.edge.opacity(0.8), lineWidth: 1))
                    .frame(height: isOpen ? 103 : 61)
                    .overlay(alignment: .top) {
                        if isOpen { reception.padding(.horizontal, 13).padding(.vertical, 10).transition(.opacity) }
                    }
                    .overlay(alignment: .top) { lid.frame(height: 61) }
                    .overlay(alignment: .top) {
                        HStack { hinge; Spacer(); hinge }.padding(.horizontal, 42).offset(y: -1)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
        }
    }

    private func toggleCover() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.48)) { isOpen.toggle() }
    }

    private var lid: some View {
        ZStack {
            cover(inner: false).modifier(BatteryLidFace(angle: isOpen ? 125 : 0, inner: false, classic: classic))
            cover(inner: true).modifier(BatteryLidFace(angle: isOpen ? 125 : 0, inner: true, classic: classic))
        }.frame(height: 61)
            .accessibilityHidden(true)
            .overlay {
                if !isOpen {
                    Button(action: toggleCover) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.text("Open battery cover"))
                        .accessibilityHint(language.text("Update status and Refresh all"))
                        .help(language.text("Update status and Refresh all"))
                }
            }
    }

    private var reception: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 6) {
                receptionRow("Last received", value: model.lastReceivedAt.map(timestamp) ?? language.text("Not yet"))
                    .help(language.text("Latest successful station update; other stations may still be waiting."))
                receptionRow("Next check", value: nextCheck(at: context.date))
                    .help(language.text("Approximate time while Catecho is running and your Mac is awake."))
                HStack(spacing: 6) {
                    Button { model.prepareEdition() } label: {
                        Label(language.text(model.fetching.isEmpty ? "Refresh all" : "Updating…"), systemImage: "arrow.clockwise")
                    }.buttonStyle(RadioServiceButtonStyle(classic: classic))
                        .disabled(!model.fetching.isEmpty)
                        .help(language.text("Refreshes your saved station choices."))
                    Spacer(minLength: 0)
                    Text(activity).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                    Button(action: toggleCover) {
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).frame(width: 22, height: 22)
                    }.buttonStyle(RadioServiceButtonStyle(classic: classic))
                        .accessibilityLabel(language.text("Close battery cover"))
                        .help(language.text("Close battery cover"))
                }
            }
            .foregroundStyle(Color.radioInk)
        }
    }
    private var activity: String {
        if !model.fetching.isEmpty { return "\(model.fetching.count) " + language.text("receiving") }
        if model.receptionIssueCount > 0 { return "\(model.receptionIssueCount) " + language.text("need attention") }
        if model.receptionPendingCount > 0 { return "\(model.receptionPendingCount) " + language.text("waiting") }
        if model.cacheWarning != nil { return language.text("Not saved offline") }
        return language.text("Reception OK")
    }
    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        return formatter.string(from: date)
    }
    private func nextCheck(at now: Date) -> String {
        if model.refreshMinutes <= 0 { return language.text("Manual") }
        guard let next = model.nextRefreshAt(now: now) else { return language.text("Updating…") }
        if next <= now { return language.text("Within a minute") }
        return "≈ " + timestamp(next)
    }
    private func receptionRow(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(language.text(title)).font(.system(size: 10, weight: .medium))
            Spacer(minLength: 0)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.85)
        }.accessibilityElement(children: .combine)
    }

    private func cover(inner: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(classic ? AnyShapeStyle(LinearGradient(colors: [.radioCream, RadioPlastic.recess, Color(red: 0.83, green: 0.81, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream))
                .overlay { if classic { RadioPlasticGrain().clipShape(RoundedRectangle(cornerRadius: 7)) } }
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(RadioPlastic.edge.opacity(0.7), lineWidth: 0.8))
                .overlay(RoundedRectangle(cornerRadius: 6).inset(by: 1.5).stroke(classic ? RadioPlastic.highlight.opacity(0.7) : .clear, lineWidth: 1))
            if inner {
                RoundedRectangle(cornerRadius: 3).inset(by: 7)
                    .stroke(RadioPlastic.edge.opacity(0.3), lineWidth: 2)
                    .shadow(color: .white.opacity(classic ? 0.55 : 0), radius: 0, x: -0.7, y: -0.7)
                HStack(spacing: 25) {
                    ForEach(0..<7) { _ in
                        Capsule().fill(RadioPlastic.edge.opacity(0.20)).frame(width: 2, height: 26)
                            .shadow(color: .white.opacity(0.6), radius: 0, x: 1, y: 0)
                    }
                }
                MoldedPlasticText(text: language.text("LOCAL RECEPTION"), size: 8, classic: classic, tracking: 1)
                    .padding(4).background(RadioPlastic.recess, in: RoundedRectangle(cornerRadius: 2))
            } else {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        MoldedPlasticText(text: language.text("BATTERY"), size: 11, classic: classic, tracking: 0.8)
                        MoldedPlasticText(text: language.text("UPDATE STATUS"), size: 8, classic: classic, tracking: 0.4)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        ForEach(0..<5) { _ in
                            Capsule().fill(RadioPlastic.edge.opacity(0.45)).frame(width: 1.5, height: 22)
                                .shadow(color: .white.opacity(classic ? 0.5 : 0), radius: 0, x: 1, y: 0.6)
                        }
                    }.padding(.horizontal, 4)
                    VStack(spacing: 3) {
                        MoldedPlasticText(text: language.text("OPEN"), size: 9, classic: classic, tracking: 0.5)
                        Image(systemName: "chevron.up").font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(RadioPlastic.edge)
                    }.frame(minWidth: 34)
                }.padding(.horizontal, 16)
            }
        }.padding(2)
    }

    private var hinge: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(classic ? AnyShapeStyle(LinearGradient(colors: [RadioPlastic.edge, .radioCream, RadioPlastic.edge], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(RadioPlastic.recess))
            .frame(width: 18, height: 5)
    }
}

/// Perspective rotation about the top edge. Positive depth moves the free edge
/// toward the viewer before it rises above the hinge, exposing the underside.
private struct BatteryLidFace: AnimatableModifier {
    var angle: Double
    let inner: Bool
    let classic: Bool
    var animatableData: Double { get { angle } set { angle = newValue } }
    func body(content: Content) -> some View {
        let radians = angle * .pi / 180
        let sine = sin(radians), cosine = cos(radians)
        var matrix = CATransform3DIdentity
        matrix.m21 = -155 * sine / 600
        matrix.m22 = cosine
        matrix.m24 = -sine / 600
        return content
            .scaleEffect(x: 1, y: inner ? -1 : 1)
            .projectionEffect(ProjectionTransform(matrix))
            .shadow(color: .black.opacity(classic ? 0.22 : 0), radius: angle > 5 ? 2 : 0.5, x: 0, y: angle > 5 ? 3 : 1)
            .opacity(inner ? (angle > 90 ? 1 : 0) : (angle <= 90 ? 1 : 0))
    }
}
