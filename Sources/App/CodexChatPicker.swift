import SwiftUI

struct CodexChatPicker: View {
    @ObservedObject var monitor: CodexMonitorModel
    let language: RadioLanguage
    let classic: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @FocusState private var searching: Bool
    private func t(_ text: String) -> String { language.text(text) }

    var body: some View {
        let sessions = monitor.sessions(now: Date())
        let matches = sessions.filter { search.isEmpty || monitor.title(for: $0.id, language: language).localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Chats · lifetime")).font(.system(size: 14, weight: .medium, design: .serif))
                Spacer()
                Button(t("Done")) { dismiss() }.buttonStyle(RadioServiceButtonStyle(classic: classic))
            }
            TextField(t("Search chats or session ID"), text: $search)
                .textFieldStyle(.plain).font(.system(size: 12)).padding(8)
                .background(Color.radioPaper, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.radioInk.opacity(0.35), lineWidth: 0.7))
                .focused($searching).accessibilityLabel(t("Search chats or session ID"))
            row(id: nil, total: monitor.lifetimeUsage(sessionID: nil)?.total, last: nil)
            Rectangle().fill(Color.radioInk.opacity(0.25)).frame(height: 0.5)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let selected = monitor.selectedSessionID, !sessions.contains(where: { $0.id == selected }), search.isEmpty {
                        row(id: selected, total: monitor.lifetimeUsage(sessionID: selected)?.total, last: nil)
                    }
                    ForEach(Array(matches.prefix(100))) { session in
                        row(id: session.id, total: session.usage.total, last: session.lastRecordedAt)
                        Rectangle().fill(Color.radioInk.opacity(0.15)).frame(height: 0.5)
                    }
                    if matches.isEmpty { Text(t(search.isEmpty || sessions.isEmpty ? monitor.lifetimeEmptyMessage : "No matching chats")).font(.system(size: 11)).padding(.vertical, 18) }
                    if matches.count > 100 { Text(t("Search to find more chats")).font(.system(size: 10)).padding(.vertical, 8) }
                }
            }.frame(maxHeight: 245)
            Text(t(monitor.snapshot?.isIndexing == true ? "Indexing earlier records… Totals are still updating." : "Lifetime includes available local records. Deleted or unrecorded usage cannot be recovered."))
                .font(.system(size: 9)).foregroundStyle(Color.radioInk.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                .help(t("Each local session is listed separately, including subagents. Names stay on this Mac."))
        }
        .padding(14).frame(width: 322, height: 370)
        .foregroundStyle(Color.radioInk).background(Color.radioCream).preferredColorScheme(.light)
        .onAppear { searching = true }
        .onExitCommand { dismiss() }
    }
    private func row(id: String?, total: Int64?, last: Date?) -> some View {
        let title = monitor.title(for: id, language: language)
        let detail = id.map { String($0.suffix(8)) } ?? ""
        let timestamp = last?.formatted(.dateTime.month().day().hour().minute()) ?? ""
        let description = [title, (total?.formatted() ?? "—") + " " + t("tokens"), t("Lifetime · available local records")].joined(separator: ", ")
        return CodexChatRow(title: title, detail: detail, timestamp: timestamp, total: total, selected: monitor.selectedSessionID == id) {
            monitor.selectSession(id); dismiss()
        }.help((id ?? t("All chats")) + "\n" + description).accessibilityLabel(description)
    }
}

private struct CodexChatRow: View {
    let title: String
    let detail: String
    let timestamp: String
    let total: Int64?
    let selected: Bool
    let choose: () -> Void
    var body: some View {
        Button(action: choose) { contents }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var contents: some View {
        HStack(spacing: 8) {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 13)).frame(width: 16).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                if !detail.isEmpty {
                    HStack(spacing: 4) {
                        Text(detail).font(.system(size: 8, design: .monospaced))
                        Text(timestamp).font(.system(size: 8))
                    }.foregroundStyle(Color.radioInk.opacity(0.75))
                }
            }
            Spacer(minLength: 2)
            Text(total?.formatted(.number.notation(.compactName)) ?? "—").font(.system(size: 11, design: .monospaced)).monospacedDigit()
        }.padding(.vertical, 9).padding(.horizontal, 5).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.radioInk.opacity(selected ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
    }
}
