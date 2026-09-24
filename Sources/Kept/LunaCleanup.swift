import Foundation
import KeptCore

enum CleanupOutcome: Equatable {
    case model(String)
    case local(String, note: String)

    var text: String {
        switch self {
        case .model(let text), .local(let text, _):
            return text
        }
    }

    var note: String? {
        switch self {
        case .model:
            return nil
        case .local(_, let note):
            return note
        }
    }
}

enum LunaCleanup {
    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    static func prepare(raw: String) async -> CleanupOutcome {
        let local = Formatter.finished(raw)
        let corrected = Formatter.format(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else { return .local(local, note: "") }
        guard let key = OpenAIKey.load() else {
            return .local(local, note: "No OpenAI key in ~/.zshenv. Inserted local text.")
        }
        do {
            let modelText = try await complete(corrected, key: key)
            guard let accepted = Cleanup.accept(source: corrected, cleaned: modelText) else {
                return .local(local, note: "Cleanup dropped a word. Inserted local text.")
            }
            let presented = Cleanup.present(accepted)
            guard !presented.isEmpty else {
                return .local(local, note: "Cleanup failed. Inserted local text.")
            }
            return .model(presented)
        } catch {
            return .local(local, note: "Cleanup failed. Inserted local text.")
        }
    }

    private static func complete(_ corrected: String, key: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": Cleanup.model,
            "reasoning": ["effort": Cleanup.reasoningEffort],
            "store": false,
            "max_output_tokens": 2000,
            "input": Cleanup.request(for: corrected),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw CleanupError.http(status)
        }
        guard let text = Cleanup.outputText(in: data) else {
            throw CleanupError.empty
        }
        return text
    }
}

private enum CleanupError: Error {
    case http(Int)
    case empty
}

enum OpenAIKey {
    static func load() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshenv")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }
            let body = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst("export ".count)) : String(trimmed)
            guard body.hasPrefix("OPENAI_API_KEY=") else { continue }
            var value = String(body.dropFirst("OPENAI_API_KEY=".count)).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, (value.hasPrefix("\""), value.hasSuffix("\"")) == (true, true)
                || (value.hasPrefix("'"), value.hasSuffix("'")) == (true, true) {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
