import Foundation
import KeptCore

@MainActor
@Observable
final class VoiceStore {
    var style: TalkingStyle
    var words: [String]
    private let url: URL

    init() {
        url = KeptPaths.applicationSupport.appendingPathComponent("voice.json")
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(VoiceMemory.self, from: data) {
            style = saved.style
            words = saved.words
        } else {
            style = .spoken
            words = []
        }
    }

    var memory: VoiceMemory {
        VoiceMemory(style: style, words: words)
    }

    func setStyle(_ style: TalkingStyle) {
        self.style = style
        save()
    }

    func add(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !words.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        words.append(trimmed)
        save()
    }

    func remove(_ word: String) {
        words.removeAll { $0 == word }
        save()
    }

    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
