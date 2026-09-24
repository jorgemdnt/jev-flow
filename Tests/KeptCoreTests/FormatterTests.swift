import Testing
@testable import KeptCore

@Test func formatterAcceptsATranscript() {
    let formatted = Formatter.format("")
    #expect(formatted.isEmpty)
}
