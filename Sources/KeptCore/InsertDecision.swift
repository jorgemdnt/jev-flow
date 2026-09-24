public struct InsertDecision: Equatable {
    public let transcript: String
    public let durationSeconds: Double

    public init(transcript: String, durationSeconds: Double) {
        self.transcript = transcript
        self.durationSeconds = durationSeconds
    }

    /// A take longer than 20 seconds with fewer than one word per four
    /// seconds is chunk loss. Do not auto-insert it.
    public var autoInsert: Bool {
        guard durationSeconds > 20 else { return true }
        let words = transcript.split(whereSeparator: \.isWhitespace).count
        return Double(words) * 4 >= durationSeconds
    }
}
