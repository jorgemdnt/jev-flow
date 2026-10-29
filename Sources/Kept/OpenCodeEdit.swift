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
        paste: @MainActor (String) async -> Bool
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

    /// Total budget for laying out a take, including a slow first byte. A
    /// stalled model pastes the text without layout.
    static let layoutBudget: Duration = .seconds(6)

    static func layout(text: String, key: String?) async -> LayoutOutcome {
        let started = ContinuousClock.now
        let outcome = await Layout.run(
            text: text, key: key,
            endpoint: endpoint, model: model, userAgent: userAgent,
            timeout: TimeInterval(layoutBudget / .seconds(1)),
            send: { request in
                try await withDeadline(layoutBudget) {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    await MainActor.run { KeyStatus.shared.openCode = KeyHealth(status: status) }
                    KeptLog.format.notice("OpenCode layout HTTP \(status), response \(data.count) bytes")
                    return (data, status)
                }
            }
        )
        let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
        KeptLog.format.notice("layout \(outcome.label, privacy: .public) in \(ms) ms, \(text.split(separator: " ").count) words")
        return outcome
    }
}

/// Runs `work` and throws a timeout when it outlives `limit`.
func withDeadline<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw URLError(.timedOut)
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
