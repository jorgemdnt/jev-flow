public enum InsertDelivery: Equatable {
    case pasted(String)
    case refused(raw: String, durationSeconds: Double)
}

public enum InsertPipeline {
    /// Finished text is what gets pasted, with a leading space when the
    /// previous insertion did not end in whitespace. InsertDecision sees the
    /// raw transcript. A refused take returns before `paste` is called.
    public static func afterTake(
        raw: String,
        durationSeconds: Double,
        previousInsertion: String = "",
        paste: (String) -> Void
    ) -> InsertDelivery {
        let formatted = TakeJoin.submission(previous: previousInsertion, next: Formatter.finished(raw))
        guard InsertDecision(transcript: raw, durationSeconds: durationSeconds).autoInsert else {
            return .refused(raw: raw, durationSeconds: durationSeconds)
        }
        paste(formatted)
        return .pasted(formatted)
    }
}
