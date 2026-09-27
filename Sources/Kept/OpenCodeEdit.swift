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
    static let endpoint = URL(string: "https://opencode.ai/zen/v1/chat/completions")!
    static let userAgent = "JevFlow/1.0"

    @MainActor static func edit(
        text: String,
        instruction: String,
        key: String?,
        matchesTarget: @MainActor () async -> Bool,
        paste: @MainActor (String) -> Bool
    ) async -> EditOutcome {
        let outcome = await EditService.run(
            selection: text, instruction: instruction, key: key,
            endpoint: endpoint, model: model, userAgent: userAgent,
            send: { request in
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run { KeyStatus.shared.openCode = KeyHealth(status: status) }
                KeptLog.edit.notice("OpenCode HTTP \(status), response \(data.count) bytes")
                return (data, status)
            },
            matchesTarget: matchesTarget, paste: paste
        )
        KeptLog.edit.notice("edit outcome \(String(describing: outcome), privacy: .public)")
        return outcome
    }
}
