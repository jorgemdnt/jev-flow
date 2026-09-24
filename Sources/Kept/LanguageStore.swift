import Foundation
import KeptCore

@MainActor
@Observable
final class LanguageStore {
    static let shared = LanguageStore()

    private(set) var code = SpokenLanguage.auto.code
    private(set) var needsOnboarding = true
    private let url: URL

    private init() {
        url = KeptPaths.applicationSupport.appendingPathComponent("language.txt")
        if let saved = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            if SpokenLanguage.choices.contains(where: { $0.code == trimmed }) {
                code = trimmed
                needsOnboarding = false
            }
        }
    }

    func choose(_ code: String) {
        let choice = SpokenLanguage.matching(code)
        self.code = choice.code
        needsOnboarding = false
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(choice.code.utf8).write(to: url, options: .atomic)
    }

    nonisolated static func currentCode() -> String {
        let url = KeptPaths.applicationSupport.appendingPathComponent("language.txt")
        guard let saved = try? String(contentsOf: url, encoding: .utf8) else { return SpokenLanguage.auto.code }
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpokenLanguage.matching(trimmed).code
    }
}
