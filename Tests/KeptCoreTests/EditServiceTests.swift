import Foundation
import Testing
@testable import KeptCore

private let endpoint = URL(string: "https://example.test/chat/completions")!
private let editedReply = Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"Ship it Friday."}}]}"#.utf8)

@MainActor private func edit(
    key: String? = "test-key",
    selection: String = "Ship it tomorrow.",
    instruction: String = "Change tomorrow to Friday.",
    status: Int = 200,
    data: Data = editedReply,
    targetMatches: Bool = true,
    pasteSucceeds: Bool = true
) async -> (EditOutcome, String) {
    var pasted = ""
    let outcome = await EditService.run(
        selection: selection, instruction: instruction, key: key,
        endpoint: endpoint, model: "test-model", userAgent: "JevFlow-test",
        send: { _ in (data, status) },
        matchesTarget: { targetMatches },
        paste: { value in pasted = value; return pasteSucceeds }
    )
    return (outcome, pasted)
}

@Test @MainActor func editUsesRequestAndVerifiedSelectionBeforePasting() async {
    var posted = ""
    let outcome = await EditService.run(
        selection: "Ship it tomorrow.", instruction: "Change tomorrow to Friday.", key: "test-key",
        endpoint: endpoint, model: "deepseek-v4.1-flash", userAgent: "JevFlow-test",
        send: { request in
            #expect(request.httpMethod == "POST")
            #expect(request.timeoutInterval == 30)
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "JevFlow-test")
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            #expect(body["model"] as? String == "deepseek-v4.1-flash")
            #expect(body["reasoning_effort"] as? String == "medium")
            return (editedReply, 200)
        },
        matchesTarget: { true }, paste: { posted = $0; return true }
    )
    #expect(outcome == .applied)
    #expect(posted == "Ship it Friday.")
}

@Test @MainActor func absentInputsNeverCallNetworkOrPaste() async {
    let cases: [(String, String, String?, EditOutcome)] = [
        ("", "change it", "key", .noSelection),
        ("old", "  ", "key", .noInstruction),
        ("old", "change it", nil, .noKey),
    ]
    for (text, instruction, key, expected) in cases {
        var pasted = false
        let outcome = await EditService.run(
            selection: text, instruction: instruction, key: key,
            endpoint: endpoint, model: "model", userAgent: "agent",
            send: { _ in Issue.record("request made with missing input"); return (editedReply, 200) },
            matchesTarget: { true }, paste: { _ in pasted = true; return true }
        )
        #expect(outcome == expected)
        #expect(!pasted)
        #expect(outcome.notice != nil)
    }
}

@Test @MainActor func httpFailuresHaveActionableAlertsAndNeverPaste() async {
    for (code, expected) in [(401, EditOutcome.unauthorized), (403, .unauthorized), (429, .rateLimited), (503, .serverUnavailable)] {
        let (outcome, pasted) = await edit(status: code)
        #expect(outcome == expected)
        #expect(pasted.isEmpty)
        #expect(outcome.notice?.body.lowercased().contains("retry") == true || outcome == .unauthorized)
    }
    let offline = await EditService.run(
        selection: "old", instruction: "change", key: "key", endpoint: endpoint, model: "model", userAgent: "agent",
        send: { _ in throw URLError(.notConnectedToInternet) },
        matchesTarget: { true }, paste: { _ in Issue.record("pasted offline"); return true }
    )
    #expect(offline == .offline)
    #expect(offline.notice?.title == "Connection lost")
    let timeout = await EditService.run(
        selection: "old", instruction: "change", key: "key", endpoint: endpoint, model: "model", userAgent: "agent",
        send: { _ in throw URLError(.timedOut) },
        matchesTarget: { true }, paste: { _ in Issue.record("pasted after timeout"); return true }
    )
    #expect(timeout == .timedOut)
    #expect(timeout.notice?.title == "Edit timed out")
}

@Test @MainActor func unusableModelOutputsNeverPaste() async {
    let replies: [(Data, EditOutcome)] = [
        (Data(#"{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}"#.utf8), .truncated),
        (Data(#"{"choices":[{"finish_reason":"content_filter","message":{"content":"partial"}}]}"#.utf8), .invalidResponse),
        (Data(#"{"choices":[{"finish_reason":"stop","message":{"content":""}}]}"#.utf8), .invalidResponse),
        (Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"Ship it tomorrow."}}]}"#.utf8), .unchanged),
        (Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"Change tomorrow to Friday."}}]}"#.utf8), .echoedInstruction),
        (Data("not JSON".utf8), .invalidResponse),
    ]
    for (reply, expected) in replies {
        let (outcome, pasted) = await edit(data: reply)
        #expect(outcome == expected)
        #expect(pasted.isEmpty)
        #expect(outcome.notice != nil)
    }
}

@Test @MainActor func targetChangeAndPasteFailureHaveNoFalseSuccess() async {
    let (changed, changedPaste) = await edit(targetMatches: false)
    #expect(changed == .selectionChanged)
    #expect(changedPaste.isEmpty)
    let (failed, _) = await edit(pasteSucceeds: false)
    #expect(failed == .pasteFailed)
    #expect(failed.notice?.title == "Couldn't paste")
}

@Test @MainActor func cancellingTheRequestNeverReadsTargetOrPastes() async {
    var pasted = false
    let task = Task { @MainActor in
        await EditService.run(
            selection: "old", instruction: "change", key: "key", endpoint: endpoint, model: "model", userAgent: "agent",
            send: { _ in try await Task.sleep(for: .seconds(5)); return (editedReply, 200) },
            matchesTarget: { Issue.record("checked target after cancel"); return true },
            paste: { _ in pasted = true; return true }
        )
    }
    try? await Task.sleep(for: .milliseconds(20))
    task.cancel()
    #expect(await task.value == .cancelled)
    #expect(!pasted)
}
