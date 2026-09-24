import Foundation
import Testing
@testable import KeptCore

@Test func cleanupRequestCarriesTheTranscriptAndTheListRule() {
    let request = Cleanup.request(for: "buy milk and eggs and bread")
    #expect(request.contains("buy milk and eggs and bread"))
    #expect(request.contains("bullet"))
    #expect(request.contains("not"))
    #expect(Cleanup.model == "gpt-6-luna")
    #expect(Cleanup.reasoningEffort == "xhigh")
}

@Test func cleanupRejectsADroppedGuardWord() {
    let source = "I'd prefer to never merge this"
    #expect(Cleanup.accept(source: source, cleaned: "I'd prefer to merge this") == nil)
    #expect(Cleanup.accept(source: source, cleaned: "I'd prefer to never land this.") == "I'd prefer to never land this.")
}

@Test func cleanupRejectsAuthRewrittenToOff() {
    #expect(Cleanup.accept(source: "use auth here", cleaned: "use off here") == nil)
    #expect(Cleanup.accept(source: "use auth here", cleaned: "use auth here.") == "use auth here.")
}

@Test func cleanupKeepsSpokenListNumbers() {
    let source = "5. alpha 6. beta"
    #expect(Cleanup.accept(source: source, cleaned: "1. alpha\n2. beta") == nil)
    let kept = Cleanup.accept(source: source, cleaned: "5. alpha\n6. beta")
    #expect(kept == "5. alpha\n6. beta")
}

@Test func cleanupAllowsABulletListWhenNoNumbersWereSpoken() {
    let source = "buy milk and eggs and bread"
    let cleaned = "• milk\n• eggs\n• bread"
    #expect(Cleanup.accept(source: source, cleaned: cleaned) == cleaned)
    #expect(Cleanup.present(cleaned) == cleaned)
}

@Test func responseTextReadsTheOutputMessage() throws {
    let json = """
    {"output":[{"type":"message","content":[{"type":"output_text","text":"• milk\\n• eggs"}]}]}
    """.data(using: .utf8)!
    #expect(Cleanup.outputText(in: json) == "• milk\n• eggs")
}
