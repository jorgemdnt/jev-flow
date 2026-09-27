import Foundation

public enum EditOutcome: Equatable, Sendable {
    case applied
    case cancelled
    case noSelection
    case noInstruction
    case noKey
    case unchanged
    case selectionChanged
    case unauthorized
    case rateLimited
    case serverUnavailable
    case offline
    case timedOut
    case truncated
    case invalidResponse
    case echoedInstruction
    case pasteFailed

    public var notice: (title: String, body: String)? {
        switch self {
        case .applied, .cancelled: nil
        case .noSelection: ("Select text", "Select the text you want to change first.")
        case .noInstruction: ("No instruction", "Say what to change, then release.")
        case .noKey: ("No OpenCode key", "Save one in JevFlow Settings, then try again.")
        case .unchanged: ("No change", "The edit was unchanged. Try a more specific instruction.")
        case .selectionChanged: ("Selection changed", "Return to the original field, select the text again, and retry.")
        case .unauthorized: ("OpenCode key rejected", "Check the key in JevFlow Settings, then retry.")
        case .rateLimited: ("OpenCode is busy", "Wait a moment, then retry the edit.")
        case .serverUnavailable: ("OpenCode unavailable", "The server could not complete the edit. Retry shortly.")
        case .offline: ("Connection lost", "Check your connection, then retry the edit.")
        case .timedOut: ("Edit timed out", "Check your connection and retry the edit.")
        case .truncated: ("Edit incomplete", "The model ran out of room. Select less text and retry.")
        case .invalidResponse: ("Edit failed", "The model returned no usable text. Retry the edit.")
        case .echoedInstruction: ("Edit failed", "The model repeated your instruction. Try saying it differently.")
        case .pasteFailed: ("Couldn't paste", "Return to the original field and retry the edit.")
        }
    }
}

public enum EditService {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)

    @MainActor public static func run(
        selection: String,
        instruction: String,
        key: String?,
        endpoint: URL,
        model: String,
        userAgent: String,
        send: Transport,
        matchesTarget: @MainActor () async -> Bool,
        paste: @MainActor (String) -> Bool
    ) async -> EditOutcome {
        guard !Task.isCancelled else { return .cancelled }
        guard !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .noSelection }
        let spoken = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return .noInstruction }
        guard let key, !key.isEmpty else { return .noKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let budget = max(4096, (selection.count + spoken.count) * 2 + 1200)
        let body: [String: Any] = [
            "model": model,
            "reasoning_effort": "medium",
            "max_tokens": budget,
            "messages": [
                ["role": "system", "content": EditPrompt.system],
                ["role": "user", "content": EditPrompt.request(text: selection, instruction: spoken)],
            ],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return .invalidResponse }
        request.httpBody = payload
        let data: Data
        let status: Int
        do {
            (data, status) = try await send(request)
        } catch {
            if Task.isCancelled { return .cancelled }
            if (error as? URLError)?.code == .timedOut { return .timedOut }
            return .offline
        }
        guard !Task.isCancelled else { return .cancelled }
        switch status {
        case 200..<300: break
        case 401, 403: return .unauthorized
        case 429: return .rateLimited
        case 500...599: return .serverUnavailable
        default: return .invalidResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .invalidResponse }
        if let choices = json["choices"] as? [[String: Any]],
           let reason = choices.first?["finish_reason"] as? String {
            if reason == "length" { return .truncated }
            if reason != "stop" { return .invalidResponse }
        }
        guard let edited = EditPrompt.text(from: data), !edited.isEmpty else { return .invalidResponse }
        if edited == selection { return .unchanged }
        if edited.caseInsensitiveCompare(spoken) == .orderedSame { return .echoedInstruction }
        guard await matchesTarget(), !Task.isCancelled else {
            return Task.isCancelled ? .cancelled : .selectionChanged
        }
        return paste(edited) ? .applied : .pasteFailed
    }
}
