import AppKit
import KeptCore
import SwiftUI

struct KeptWindow: View {
    let session: Session
    @Bindable var pages: KeptPages
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LucideMark(icon: .option, size: 18, color: KeptColor.onAccent)
                    .frame(width: 34, height: 34)
                    .background(KeptColor.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text("JevFlow")
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 40)
            KeptSectionLabel(text: "WORKSPACE")
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            VStack(spacing: 4) {
                nav("History", .clock, .history)
                nav("Dictionary", .book, .dictionary)
                nav("Settings", .settings, .settings)
            }
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    LucideMark(icon: .option, size: 15, color: KeptColor.accent)
                    Text("RIGHT OPTION")
                        .font(KeptType.eyebrow)
                        .tracking(0.8)
                }
                Text("Hold anywhere to dictate")
                    .font(KeptType.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KeptColor.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 42)
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
        .frame(width: 212)
        .background(KeptColor.rail)
        .overlay(alignment: .trailing) { KeptColor.border.frame(width: 1) }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KeptTheme.gutter) {
                switch pages.page {
                case .history:
                    HistoryPage(session: session)
                case .dictionary:
                    DictionaryPage(store: session.voice)
                case .style, .settings:
                    SettingsPage()
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, KeptTheme.margin)
            .padding(.top, 48)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(pages.page)
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .animation(reduceMotion ? nil : KeptTheme.animation, value: pages.page)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selected = pages.page == page
        Button {
            withAnimation(reduceMotion ? nil : KeptTheme.animation) {
                pages.page = page
            }
        } label: {
            HStack(spacing: 10) {
                LucideMark(icon: icon, size: 17, color: selected ? KeptColor.accent : .secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? KeptColor.accent : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(KeptColor.selected)
                        .matchedGeometryEffect(id: "selection", in: selection)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .onHover { inside in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                hovering = inside
            }
        }
    }
}

private struct HistoryPage: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: KeptTheme.gutter) {
            KeptHeader(eyebrow: "YOUR WORDS", title: "History", subtitle: "Your recent takes, ready when you need them.")
            HStack(spacing: 10) {
                Circle()
                    .fill(KeptColor.accent)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Capture status")
                        .font(.system(size: 14, weight: .semibold))
                    Text(session.status)
                        .font(KeptType.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KeptColor.tint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            if session.takes.isEmpty {
                KeptCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nothing here yet")
                            .font(KeptType.title)
                        Text("Hold Right Option in any text field. Your takes will appear here.")
                            .font(KeptType.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                KeptSectionLabel(text: "RECENT TAKES")
                    .padding(.top, 6)
                ForEach(session.takes) { take in
                    KeptCard {
                        HStack(alignment: .top, spacing: 16) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(KeptColor.accent)
                                .frame(width: 3, height: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 16) {
                                Text(take.insertedText ?? take.rawTranscript)
                                    .font(KeptType.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 16) {
                                    Text(String(format: "%.1f s", take.durationSeconds))
                                        .font(KeptType.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    Button("Dismiss") { session.dismiss(take.id) }
                                        .buttonStyle(.plain)
                                        .font(KeptType.secondary)
                                        .foregroundStyle(.secondary)
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
                                }
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
        VStack(alignment: .leading, spacing: KeptTheme.gutter) {
            KeptHeader(
                eyebrow: "MAKE IT YOURS",
                title: "Dictionary",
                subtitle: "Names and product terms. A unique name pastes as the @handle."
            )
            KeptCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a word")
                        .font(KeptType.title)
                    Text("Save the spelling you want to see in your text.")
                        .font(KeptType.secondary)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        TextField("Word or @handle", text: $draft)
                            .textFieldStyle(.plain)
                            .font(KeptType.body)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(KeptColor.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .accessibilityLabel("New dictionary word")
                            .onSubmit(add)
                        Button("Add", action: add)
                            .buttonStyle(KeptPrimaryButton())
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            KeptSectionLabel(text: "SAVED WORDS")
                .padding(.top, 6)
            if store.words.isEmpty {
                KeptCard {
                    Text("No words saved yet.")
                        .font(KeptType.secondary)
                        .foregroundStyle(.secondary)
                }
            } else {
                KeptCard {
                    VStack(spacing: 0) {
                        ForEach(Array(store.words.enumerated()), id: \.element) { index, word in
                            HStack(spacing: 12) {
                                Text(word)
                                    .font(KeptType.body)
                                    .textSelection(.enabled)
                                Spacer(minLength: 8)
                                Button("Remove") { store.remove(word) }
                                    .buttonStyle(.plain)
                                    .font(KeptType.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Remove \(word)")
                            }
                            .padding(.vertical, 11)
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
    private let keys = KeyStatus.shared

    var body: some View {
        VStack(alignment: .leading, spacing: KeptTheme.gutter) {
            KeptHeader(
                eyebrow: "PREFERENCES",
                title: "Settings",
                subtitle: "Speech stays on this Mac. Jev chooses the format and dictionary words without rewriting your sentence."
            )
            KeptSectionLabel(text: "DICTATION")
                .padding(.top, 6)
            LanguageSettings(store: LanguageStore.shared)
            MicrophoneSettings(store: MicStore.shared)
            KeptSectionLabel(text: "CONNECTIONS")
                .padding(.top, 6)
            KeptCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TypeSafe")
                                .font(KeptType.title)
                            Text("Formats your finished take. \(status)")
                                .font(KeptType.secondary)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if source == .saved {
                            KeyHealthTag(health: keys.typeSafe) {
                                Task { await keys.checkTypeSafe() }
                            }
                        }
                    }
                    SecureField("TypeSafe API key", text: $draft)
                        .textFieldStyle(.plain)
                        .font(KeptType.body)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(KeptColor.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityLabel("TypeSafe API key")
                    HStack(spacing: 16) {
                        Button("Save key") { save() }
                            .buttonStyle(KeptPrimaryButton())
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if source == .saved {
                            Button("Remove saved key") { remove() }
                                .buttonStyle(.plain)
                                .font(KeptType.secondary)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if failed {
                        Text("Could not save the key.")
                            .font(KeptType.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            KeptCard {
                OpenCodeKeyCard()
            }
        }
        .onAppear { source = TypeSafeKey.source() }
        .task { await keys.checkTypeSafe() }
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
            Task { await keys.checkTypeSafe() }
        }
    }

    private func remove() {
        TypeSafeKey.delete()
        source = TypeSafeKey.source()
        keys.typeSafe = .unknown
    }
}

private struct OpenCodeKeyCard: View {
    @State private var draft = ""
    @State private var source = OpenCodeKey.source()
    @State private var failed = false
    private let keys = KeyStatus.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenCode")
                        .font(KeptType.title)
                    Text("Edits selected text with DeepSeek V4.1 Flash. \(source == .saved ? "Key saved." : "No key saved yet.")")
                        .font(KeptType.secondary)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if source == .saved {
                    KeyHealthTag(health: keys.openCode) {
                        Task { await keys.checkOpenCode() }
                    }
                }
            }
            SecureField("OpenCode API key", text: $draft)
                .textFieldStyle(.plain)
                .font(KeptType.body)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(KeptColor.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityLabel("OpenCode API key")
            HStack(spacing: 16) {
                Button("Save OpenCode key") {
                    failed = !OpenCodeKey.save(draft)
                    if !failed {
                        draft = ""
                        source = OpenCodeKey.source()
                        Task { await keys.checkOpenCode() }
                    }
                }
                .buttonStyle(KeptPrimaryButton())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if source == .saved {
                    Button("Remove OpenCode key") {
                        OpenCodeKey.delete()
                        source = OpenCodeKey.source()
                        keys.openCode = .unknown
                    }
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
        .onAppear { source = OpenCodeKey.source() }
        .task { await keys.checkOpenCode() }
    }
}

/// The corner tag on a key card: a dot and a word. Click to check again.
private struct KeyHealthTag: View {
    let health: KeyHealth
    let recheck: () -> Void

    var body: some View {
        Button(action: recheck) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(health.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(health == .working ? Color.primary.opacity(0.75) : color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Click to check the key again")
        .disabled(health == .checking)
    }

    private var color: Color {
        switch health {
        case .working: .green
        case .rejected: .red
        case .unreachable: .orange
        case .unknown, .checking: .secondary
        }
    }
}

private struct KeptHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            KeptSectionLabel(text: eyebrow)
            Text(title)
                .font(KeptType.page)
            Text(subtitle)
                .font(KeptType.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }
}
