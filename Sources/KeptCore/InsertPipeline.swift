public enum InsertDelivery: Equatable {
    case pasted(String)
    case refused(raw: String, durationSeconds: Double)
}

public enum InsertPipeline {
    /// Finished text is what gets pasted. A leading space is added unless the
    /// field already ends in whitespace. InsertDecision sees the raw transcript.
    /// A refused take returns before `paste` is called.
    public static func afterTake(
        raw: String,
        durationSeconds: Double,
        previousInsertion: String = "",
        field: FieldJoin = .unknown,
        paste: (String) -> Void
    ) -> InsertDelivery {
        let formatted = TakeJoin.submission(
            previous: previousInsertion,
            next: Formatter.finished(raw),
            field: field
        )
        guard InsertDecision(transcript: raw, durationSeconds: durationSeconds).autoInsert else {
            return .refused(raw: raw, durationSeconds: durationSeconds)
        }
        paste(formatted)
        return .pasted(formatted)
    }
}
