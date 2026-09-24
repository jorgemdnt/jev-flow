public enum InsertDelivery: Equatable {
    case pasted(String)
    case refused(raw: String, durationSeconds: Double)
}

public enum InsertPipeline {
    /// Formatter output is what gets pasted. InsertDecision sees the raw
    /// transcript. A refused take returns before `paste` is called.
    public static func afterTake(
        raw: String,
        durationSeconds: Double,
        paste: (String) -> Void
    ) -> InsertDelivery {
        let formatted = Formatter.format(raw)
        guard InsertDecision(transcript: raw, durationSeconds: durationSeconds).autoInsert else {
            return .refused(raw: raw, durationSeconds: durationSeconds)
        }
        paste(formatted)
        return .pasted(formatted)
    }
}
