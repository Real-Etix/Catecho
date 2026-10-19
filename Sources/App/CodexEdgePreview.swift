import SwiftUI

struct CodexEdgePreview: View {
    @ObservedObject var monitor: CodexMonitorModel
    let language: RadioLanguage
    let classic: Bool
    let open: () -> Void
    private func t(_ text: String) -> String { language.text(text) }
    private var scope: String { monitor.title(for: monitor.selectedSessionID, language: language) }
    private var unit: String { t(monitor.window == .second ? "tokens / sec" : "tokens") }
    private var status: String {
        guard let snapshot = monitor.snapshot, !snapshot.isIndexing else { return "INDEXING" }
        if snapshot.issue != nil { return "SAVED / UNAVAILABLE" }
        return snapshot.warning != nil ? "PARTIAL HISTORY" : ""
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in button(now: context.date) }
    }
    private func button(now: Date) -> some View {
        let label = [t("Open Codex activity"), scope, monitor.reading(now: now) + " " + unit, t(status)].joined(separator: ", ")
        let hint = [t("Open Codex activity"), scope, t(status), t("Uses the selected time view; readings update about every five seconds while tucked.")].joined(separator: "\n")
        return Button(action: open) { display(now: now) }
            .buttonStyle(.plain).help(hint).accessibilityLabel(label)
    }
    private func display(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            heading
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(monitor.reading(now: now, compact: true)).font(.system(size: 21, weight: .medium, design: .monospaced)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(unit).font(.system(size: 7)).lineLimit(1)
            }
            Text(scope).font(.system(size: 9)).lineLimit(1).truncationMode(.middle)
        }
        .foregroundStyle(Color.radioInk)
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(width: 124, height: 70, alignment: .leading)
        .background(screen)
        .padding(4).background(shell)
        .contentShape(RoundedRectangle(cornerRadius: 11))
    }
    private var heading: some View {
        HStack {
            Text("Codex").font(.system(size: 10, weight: .medium, design: .serif))
            Spacer(minLength: 0)
            if !status.isEmpty { Image(systemName: status == "INDEXING" ? "clock" : "exclamationmark.triangle").font(.system(size: 8)).accessibilityHidden(true) }
            Text(t(monitor.window == .second ? "SEC" : monitor.window == .minute ? "MIN" : "HR")).font(.system(size: 8, design: .monospaced))
        }
    }
    private var screen: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.radioPaper.shadow(.inner(color: .black.opacity(classic ? 0.2 : 0), radius: 2, x: 1, y: 2)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.radioInk.opacity(0.5), lineWidth: 0.7))
    }
    private var shell: some View {
        let material = classic ? AnyShapeStyle(LinearGradient(colors: [.white, .radioCream, Color(red: 0.79, green: 0.75, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream)
        return RoundedRectangle(cornerRadius: 11).fill(material)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.radioInk.opacity(0.55), lineWidth: 0.7))
            .shadow(color: .black.opacity(classic ? 0.16 : 0), radius: 1, x: 0, y: 1)
    }
}
