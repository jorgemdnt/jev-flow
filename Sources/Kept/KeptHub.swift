import AppKit
import KeptCore
import SwiftUI

struct KeptWindow: View {
    let session: Session
    @Bindable var pages: KeptPages
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KeptColor.canvas)
        .frame(minWidth: 820, minHeight: 540)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("JevFlow")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            nav("History", .clock, .history)
            nav("Dictionary", .book, .dictionary)
            nav("Settings", .settings, .settings)
            Spacer()
            HStack(spacing: 6) {
                LucideMark(icon: .option, size: 14)
                Text("Hold right")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 42)
        .padding(.horizontal, 10)
        .padding(.bottom, 16)
        .frame(width: 196)
        .background(KeptColor.rail)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch pages.page {
                case .history:
                    HistoryPage(session: session)
                case .dictionary:
                    DictionaryPage(store: session.voice)
                case .style, .settings:
                    SettingsPage()
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 36)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(pages.page)
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .animation(.smooth(duration: 0.28), value: pages.page)
    }

    private func nav(_ title: String, _ icon: LucideIcon, _ page: KeptPage) -> some View {
        NavRow(title: title, icon: icon, page: page, pages: pages, selection: selection)
    }
}

private struct NavRow: View {
    let title: String
    let icon: LucideIcon
    let page: KeptPage
    var pages: KeptPages
    var selection: Namespace.ID
    @State private var hovering = false

    var body: some View {
        let selected = pages.page == page
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                pages.page = page
            }
        } label: {
            HStack(spacing: 8) {
                LucideMark(icon: icon, size: 16)
                    .frame(width: 16, height: 16)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(KeptColor.selected)
                        .matchedGeometryEffect(id: "selection", in: selection)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.15)) {
                hovering = inside
            }
        }
    }
}

private struct HistoryPage: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeptHeader(title: "History", subtitle: session.status)
            if session.takes.isEmpty {
                KeptCard {
                    Text("No takes yet. Hold Right Option in any text field.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(session.takes) { take in
                    KeptCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(take.insertedText ?? take.rawTranscript)
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                Text(String(format: "%.1f s", take.durationSeconds))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if take.insertedText != nil {
                                    Button("Insert again") { session.insertAgain(take.id) }
                                        .buttonStyle(KeptPrimaryButton())
                                } else if session.refusesAutoInsert(take) {
                                    Button("Insert raw") { session.insertRaw(take.id) }
                                        .buttonStyle(KeptPrimaryButton())
                                } else {
                                    Button("Insert") { session.insertKept(take.id) }
                                        .buttonStyle(KeptPrimaryButton())
                                }
                                Button("Dismiss") { session.dismiss(take.id) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DictionaryPage: View {
    let store: VoiceStore
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeptHeader(
                title: "Dictionary",
                subtitle: "Names and product terms. If you say one, cleanup keeps that spelling."
            )
            HStack(spacing: 8) {
                TextField("Add a word", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KeptColor.card, in: Capsule())
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(KeptPrimaryButton())
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if store.words.isEmpty {
                KeptCard {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                KeptCard {
                    VStack(spacing: 0) {
                        ForEach(Array(store.words.enumerated()), id: \.element) { index, word in
                            HStack {
                                Text(word)
                                    .font(.system(size: 14))
                                Spacer()
                                Button("Remove") { store.remove(word) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            if index < store.words.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func add() {
        store.add(draft)
        draft = ""
    }
}

private struct SettingsPage: View {
    @State private var draft = ""
    @State private var source = TypeSafeKey.source()
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KeptHeader(
                title: "Settings",
                subtitle: "Jev chooses the format and which dictionary word you meant. It does not rewrite the sentence. Speech stays on this Mac."
            )
            LanguageSettings(store: LanguageStore.shared)
            MicrophoneSettings(store: MicStore.shared)
            KeptCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(status)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    SecureField("TypeSafe API key", text: $draft)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(KeptColor.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    HStack {
                        Button("Save key") { save() }
                            .buttonStyle(KeptPrimaryButton())
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if source == .saved {
                            Button("Remove saved key") { remove() }
                                .buttonStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if failed {
                        Text("Could not save the key.")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear { source = TypeSafeKey.source() }
    }

    private var status: String {
        switch source {
        case .saved: "Key saved in this app."
        case .missing: "No key saved yet."
        }
    }

    private func save() {
        failed = !TypeSafeKey.save(draft)
        if !failed {
            draft = ""
            source = TypeSafeKey.source()
        }
    }

    private func remove() {
        TypeSafeKey.delete()
        source = TypeSafeKey.source()
    }
}

private struct KeptHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct KeptCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06))
            )
    }
}

struct KeptPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .foregroundStyle(KeptColor.canvas)
    }
}

enum KeptColor {
    static let canvas = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.11, alpha: 1)
            : NSColor(calibratedRed: 0.965, green: 0.957, blue: 0.945, alpha: 1)
    }))
    static let rail = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.09, alpha: 1)
            : NSColor(calibratedRed: 0.945, green: 0.933, blue: 0.914, alpha: 1)
    }))
    static let card = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor.white
    }))
    static let field = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.12, alpha: 1)
            : NSColor(calibratedWhite: 0.96, alpha: 1)
    }))
    static let selected = Color.primary.opacity(0.08)
}
