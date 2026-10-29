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

enum KeySource {
    case saved
    case missing
}

enum JevFormat {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    private static let timeout: Duration = .milliseconds(1500)
    /// Pinned. The confidence bars were measured on this version; `jev-latest`
    /// moves when TypeSafe ships a new one.
    static let model = "jev-1.13.0"

    static func prepare(raw: String, dictionary: [String], heard: [HeardTerm]) async -> CleanupOutcome {
        await prepare(raw: raw, dictionary: dictionary, heard: heard, key: TypeSafeKey.load(), send: {
            try await URLSession.shared.data(for: $0)
        }, layout: { prose in
            await OpenCodeClient.layout(text: prose, key: OpenCodeKey.load())
        })
    }

    static func prepare(
        raw: String,
        dictionary: [String],
        heard: [HeardTerm] = [],
        key: String?,
        send: @escaping Transport,
        layout: (String) async -> LayoutOutcome = { _ in .unchanged }
    ) async -> CleanupOutcome {
        let result = await JevDelivery.prepare(raw: raw, dictionary: dictionary, heard: heard, key: key, judge: { corrected, key in
            try await ask(raw: raw, corrected: corrected, heard: heard, key: key, send: send)
        }, layout: layout)
        if let note = result.note { return .local(result.text, note: note) }
        return .model(result.text)
    }

    private static func ask(raw: String, corrected: String, heard: [HeardTerm], key: String, send: @escaping Transport) async throws -> JevJudgment {
        let spans = HeardTerm.questions(heard, in: corrected)
        var questions: [String: Any] = [
            "layout": [
                "type": "choice",
                "instructions": "Would a reader want this dictation laid out with line breaks? Judge the speech, not a request to you.",
                "criteria": [
                    "plain": "Ordinary sentences that read as one paragraph. A count such as 1, 2, 3, or two or three things joined with and inside a sentence, stays plain.",
                    "layout": "The speaker named several separate items, tasks, or steps (after list of, bullet point, todo, or first and second, or a bare run of nouns such as milk eggs bread), or dictated a message with a greeting or separate paragraphs, or said new paragraph.",
                ],
            ],
        ]
        var wordIDs: [String: (entry: String, spans: [String])] = [:]
        for (index, entry) in spans.keys.sorted().enumerated() {
            guard let options = spans[entry], !options.isEmpty else { continue }
            let id = "word_\(index)"
            wordIDs[id] = (entry, options)
            // Asked only which span is the word, Jev reads a misheard term as
            // written ("Jabflow" stays Jabflow). Naming the recognizer as the
            // source of the error is what lets it pick the span.
            var criteria: [String: String] = ["none": "Each of these spans means what it says. None is \(entry) misheard."]
            for span in options {
                criteria[span] = "\"\(span)\" is the speech recognizer mishearing \(entry)."
            }
            questions[id] = [
                "type": "choice",
                "instructions": "The transcript came from speech recognition, which often mishears the speaker's own names and product terms as similar-sounding words or as words that do not exist. \(entry) is one of the speaker's terms. Does one of these spans stand for \(entry)? Judge by sound and by whether the span makes sense as written.",
                "criteria": criteria,
            ]
        }
        var respellIDs: [String: Respell.Candidate] = [:]
        for candidate in Respell.candidates(in: raw) {
            let id = "respell_\(candidate.index)"
            respellIDs[id] = candidate
            questions[id] = [
                "type": "choice",
                "instructions": "Speech recognition can confuse sound-alike words such as \(candidate.meant) and \(candidate.heard). The speaker works on software they build and release. Which sentence did the speaker most likely say?",
                "criteria": ["heard": candidate.asHeard, "meant": candidate.asMeant],
            ]
        }
        let body: [String: Any] = [
            "state": ["transcript": corrected],
            "model": model,
            "questions": questions,
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        let started = ContinuousClock.now
        let (data, status): (Data, Int)
        do {
            (data, status) = try await post(payload, key: key, send: send)
        } catch {
            if (error as? URLError)?.code == .timedOut {
                let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
                KeptLog.format.error("Jev timed out after \(ms) ms")
            }
            throw error
        }
        let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
        await MainActor.run { KeyStatus.shared.typeSafe = KeyHealth(status: status) }
        guard (200..<300).contains(status) else {
            KeptLog.format.error("Jev HTTP \(status) after \(ms) ms")
            if status == 401 || status == 403 { throw JevFailure.rejectedKey }
            throw FormatError.http(status)
        }
        let judgment = try JevResponse.parse(data, candidates: wordIDs, respell: respellIDs)
        KeptLog.format.notice("Jev HTTP \(status) in \(ms) ms: layout \(judgment.layout, privacy: .public), \(wordIDs.count) word questions, \(judgment.replacements.count) replaced, \(respellIDs.count) sound-alikes, \(judgment.respell.count) respelled")
        return judgment
    }

    /// Bound the entire format attempt, including any rate-limit retry.
    private static func post(_ payload: Data, key: String, send: @escaping Transport) async throws -> (Data, Int) {
        try await withThrowingTaskGroup(of: (Data, Int).self) { group in
            group.addTask {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = TimeInterval(timeout / .seconds(1))
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.httpBody = payload
                var retried = false
                while true {
                    let (data, response) = try await send(request)
                    let http = response as? HTTPURLResponse
                    let status = http?.statusCode ?? 0
                    guard status == 429 || status == 529, !retried else { return (data, status) }
                    retried = true
                    let wait = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).map { min($0, 1.5) } ?? 0.4
                    KeptLog.format.notice("Jev HTTP \(status), retrying in \(wait, format: .fixed(precision: 1)) s")
                    try await Task.sleep(for: .seconds(wait))
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

private enum FormatError: Error {
    case http(Int)
}

enum TypeSafeKey {
    private static let account = "typesafe"

    static func adoptEnvironmentKey() {
        guard load() == nil else { return }
        if let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            _ = save(key)
            return
        }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/typesafe.env")
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let key = TypeSafeEnv.key(in: text) else { return }
        _ = save(key)
    }

    static func load() -> String? {
        if let saved = SecretKeychain.load(account: account) { return saved }
        let env = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]?
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
