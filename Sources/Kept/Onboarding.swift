import AppKit
import KeptCore
import SwiftUI

struct LanguageOnboarding: View {
    var store: LanguageStore
    var onDone: () -> Void
    @State private var code = SpokenLanguage.auto.code

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                LucideMark(icon: .option, size: 18)
                Text("JevFlow")
                    .font(.system(size: 13, weight: .semibold))
            }
            Text("Which language?")
                .font(.system(size: 28, weight: .semibold))
            Text("Auto detects it. Pin one if you always speak the same language.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SpokenLanguage.choices, id: \.code) { language in
                        Button {
                            code = language.code
                        } label: {
                            HStack {
                                Text(language.name)
                                Spacer()
                                if code == language.code {
                                    Text("Selected")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.system(size: 14, weight: code == language.code ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .background(
                                code == language.code ? KeptColor.selected : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
            }
            .frame(height: 280)
            .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button("Continue") {
                store.choose(code)
                onDone()
            }
            .buttonStyle(KeptPrimaryButton())
        }
        .padding(28)
        .frame(width: 420)
        .background(KeptColor.canvas)
    }
}

struct LanguageSettings: View {
    @Bindable var store: LanguageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Language")
                .font(.system(size: 13, weight: .semibold))
            Text(SpokenLanguage.matching(store.code).code == "auto" ? "Detecting the language." : "Pinned to \(SpokenLanguage.matching(store.code).name).")
                .font(.system(size: 13))
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
