public struct PasteAttempt<Value> {
    public let value: Value
    public let leadingTyped: Bool
}

/// The keyboard separator is separate from the pasteboard body: editors can
/// strip a pasted trailing space. A failed leading keystroke never prevents
/// the actual words from being pasted.
public enum PasteActions {
    @MainActor public static func perform<Value>(
        text: String,
        leading: Bool,
        typeSpace: () -> Bool,
        paste: (String) async -> Value,
        didPaste: (Value) -> Bool,
        afterPaste: () -> Void
    ) async -> PasteAttempt<Value> {
        let leadingTyped = leading && typeSpace()
        let body = text.hasSuffix(" ") ? String(text.dropLast()) : text
        let value = await paste(body)
        if didPaste(value), text.hasSuffix(" ") { afterPaste() }
        return PasteAttempt(value: value, leadingTyped: leadingTyped)
    }
}
