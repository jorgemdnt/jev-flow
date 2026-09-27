import Testing
@testable import KeptCore

private enum PasteStatus { case pasted, failed }

@Test func aPasteTypesTheNeededGapThenBodyThenTrailingSpace() {
    var events: [String] = []
    let attempt: PasteAttempt<PasteStatus> = PasteActions.perform(
        text: "Next. ", leading: true,
        typeSpace: { events.append("space"); return true },
        paste: { events.append("paste:\($0)"); return PasteStatus.pasted },
        didPaste: { $0 == PasteStatus.pasted },
        afterPaste: { events.append("trailing space") }
    )
    #expect(attempt.value == .pasted)
    #expect(attempt.leadingTyped)
    #expect(events == ["space", "paste:Next.", "trailing space"])
}

@Test func anUnknownCaretOrAFailedSeparatorNeverAddsALeadingPasteSpace() {
    var events: [String] = []
    let attempt: PasteAttempt<PasteStatus> = PasteActions.perform(
        text: "Next. ", leading: true,
        typeSpace: { events.append("failed separator"); return false },
        paste: { events.append("paste:\($0)"); return PasteStatus.pasted },
        didPaste: { $0 == PasteStatus.pasted },
        afterPaste: { events.append("trailing space") }
    )
    #expect(!attempt.leadingTyped)
    #expect(events == ["failed separator", "paste:Next.", "trailing space"])
    events.removeAll()
    _ = PasteActions.perform(
        text: "Again. ", leading: false,
        typeSpace: { events.append("unexpected separator"); return true },
        paste: { events.append("paste:\($0)"); return PasteStatus.pasted },
        didPaste: { $0 == PasteStatus.pasted },
        afterPaste: { events.append("trailing space") }
    )
    #expect(events == ["paste:Again.", "trailing space"])
}

@Test(arguments: [FieldJoin.needsSpace, .separated, .unknown])
func aLeadingWhitespaceTakeUsesTheNormalizedBodyToDecideTheTypedGap(_ field: FieldJoin) {
    let submitted = TakeJoin.submission(previous: "Done. ", next: "  Hello.  ", field: field)
    let leading = TakeJoin.needsSeparator(previous: "Done. ", next: "  Hello.  ", field: field)
    var events: [String] = []
    let attempt = PasteActions.perform(
        text: submitted, leading: leading,
        typeSpace: { events.append("gap"); return true },
        paste: { events.append("paste:\($0)"); return true },
        didPaste: { $0 },
        afterPaste: { events.append("trailing") }
    )
    #expect(submitted == "Hello. ")
    #expect(attempt.leadingTyped == (field == .needsSpace))
    let expected = field == .needsSpace
        ? ["gap", "paste:Hello.", "trailing"]
        : ["paste:Hello.", "trailing"]
    #expect(events == expected)
    #expect(!TakeJoin.needsSeparator(previous: "Done.", next: " \n ", field: field))
}

@Test func aFailedPasteDoesNotTypeATrailingSpace() {
    var events: [String] = []
    let attempt: PasteAttempt<PasteStatus> = PasteActions.perform(
        text: "Next. ", leading: false,
        typeSpace: { events.append("unexpected separator"); return true },
        paste: { events.append("paste:\($0)"); return PasteStatus.failed },
        didPaste: { $0 == PasteStatus.pasted },
        afterPaste: { events.append("unexpected trailing") }
    )
    #expect(attempt.value == .failed)
    #expect(events == ["paste:Next."])
}
