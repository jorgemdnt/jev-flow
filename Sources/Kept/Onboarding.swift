import AppKit
import KeptCore
import SwiftUI

struct LanguageOnboarding: View {
    var store: LanguageStore
    var onDone: () -> Void
    @State private var code = SpokenLanguage.auto.code

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LucideMark(icon: .option, size: 19, color: KeptColor.onAccent)
                    .frame(width: 38, height: 38)
                    .background(KeptColor.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                Text("JevFlow")
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.bottom, 34)
            KeptSectionLabel(text: "LET'S GET STARTED")
                .padding(.bottom, 8)
            Text("Which language do you speak?")
                .font(.system(size: 27, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            Text("Auto detects it. Pin one if you always speak the same language.")
                .font(KeptType.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 22)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(SpokenLanguage.choices, id: \.code) { language in
                        Button {
                            code = language.code
                        } label: {
                            HStack(spacing: 10) {
                                Text(language.name)
                                Spacer(minLength: 0)
                                if code == language.code {
                                    Text("Selected")
                                        .font(KeptType.caption)
                                        .foregroundStyle(KeptColor.accent)
                                }
                            }
                            .font(.system(size: 13, weight: code == language.code ? .semibold : .regular))
                            .foregroundStyle(code == language.code ? KeptColor.accent : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .background(
                                code == language.code ? KeptColor.selected : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(code == language.code ? "Selected" : "")
                    }
                }
                .padding(7)
            }
            .frame(height: 240)
            .background(KeptColor.card, in: RoundedRectangle(cornerRadius: KeptTheme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KeptTheme.radius, style: .continuous)
                    .strokeBorder(KeptColor.border)
            }
            .padding(.bottom, 24)
            Button("Continue") {
                store.choose(code)
                onDone()
            }
            .buttonStyle(KeptPrimaryButton())
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(28)
        .frame(width: 440, height: 570, alignment: .topLeading)
        .background(KeptColor.canvas)
    }
}

struct LanguageSettings: View {
    @Bindable var store: LanguageStore

    var body: some View {
        KeptCard {
            VStack(alignment: .leading, spacing: 9) {
                Text("Language")
                    .font(KeptType.title)
                Text(SpokenLanguage.matching(store.code).code == "auto" ? "Detecting the language." : "Pinned to \(SpokenLanguage.matching(store.code).name).")
                    .font(KeptType.secondary)
                    .foregroundStyle(.secondary)
                Picker("Language", selection: Binding(
                    get: { store.code },
                    set: { store.choose($0) }
                )) {
                    ForEach(SpokenLanguage.choices, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Spoken language")
            }
        }
    }
}
