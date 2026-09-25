import Foundation
import KeptCore

enum OpenCodeKey {
    private static let account = "opencode"

    static func load() -> String? {
        if let saved = SecretKeychain.load(account: account) { return saved }
        let env = ProcessInfo.processInfo.environment["OPENCODE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let env, !env.isEmpty else { return nil }
        return env
    }

    static func source() -> KeySource {
        SecretKeychain.load(account: account) == nil ? .missing : .saved
    }

    static func save(_ secret: String) -> Bool {
        SecretKeychain.save(secret, account: account)
    }

    static func delete() {
        SecretKeychain.delete(account: account)
    }
}

enum OpenCodeClient {
    static let model = "deepseek-v4.1-flash"
    private static let endpoint = URL(string: "https://opencode.ai/zen/v1/chat/completions")!

    static func edit(text: String, instruction: String) async -> String? {
        guard let key = OpenCodeKey.load() else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JevFlow/1.0", forHTTPHeaderField: "User-Agent")
        let budget = max(4096, text.count + instruction.count + 1200)
        let body: [String: Any] = [
            "model": model,
            "reasoning_effort": "medium",
            "max_tokens": budget,
            "messages": [
                ["role": "system", "content": "Return only the edited text."],
                ["role": "user", "content": EditPrompt.request(text: text, instruction: instruction)],
            ],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = payload
        guard let (data, urlResponse) = try? await URLSession.shared.data(for: request),
              let http = urlResponse as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return EditPrompt.text(from: data)
    }
}
