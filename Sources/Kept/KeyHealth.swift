import Foundation
import Observation

/// Whether a saved key works, from the last real call or check. Settings shows
/// it as a dot in the corner of each key card.
enum KeyHealth: Equatable {
    case unknown
    case checking
    case working
    case rejected(Int)
    case unreachable

    /// An HTTP status from a call that carried the key.
    init(status: Int) {
        switch status {
        case 200..<300: self = .working
        case 401, 403: self = .rejected(status)
        default: self = .unreachable
        }
    }

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .checking: "Checking…"
        case .working: "Working"
        case .rejected(let status): "Key rejected (\(status))"
        case .unreachable: "Can't reach the service"
        }
    }
}

@MainActor
@Observable
final class KeyStatus {
    static let shared = KeyStatus()

    var typeSafe = KeyHealth.unknown
    var openCode = KeyHealth.unknown

    /// Read-only: lists models. It sends the key and no text.
    func checkTypeSafe() async {
        guard let key = TypeSafeKey.load() else {
            typeSafe = .unknown
            return
        }
        typeSafe = .checking
        var request = URLRequest(url: URL(string: "https://api.typesafe.ai/v1/models")!)
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        typeSafe = await Self.health(of: request)
    }

    /// OpenCode lists models for any key, so that list proves nothing. A
    /// one-token completion is the cheapest call that checks the key.
    func checkOpenCode() async {
        guard let key = OpenCodeKey.load() else {
            openCode = .unknown
            return
        }
        openCode = .checking
        var request = URLRequest(url: OpenCodeClient.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(OpenCodeClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": OpenCodeClient.model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ok"]],
        ])
        openCode = await Self.health(of: request)
    }

    private static func health(of request: URLRequest) async -> KeyHealth {
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        return KeyHealth(status: http.statusCode)
    }
}
