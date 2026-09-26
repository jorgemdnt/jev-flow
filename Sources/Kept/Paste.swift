import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
enum FocusedAppPaste {
    enum Result: Equatable {
        case pasted
        case accessibilityMissing
        case failed
    }

    private struct Snapshot: Sendable {
        struct Item: Sendable {
            var entries: [(String, Data)]
        }

        var items: [Item]
    }

    private static var restoreGeneration = 0

    /// Saves the pasteboard, posts Command-V, then restores. Does nothing
    /// when Accessibility permission is missing.
    static func paste(_ text: String) -> Result {
        guard AXIsProcessTrusted() else { return .accessibilityMissing }
        guard !text.isEmpty else { return .failed }

        let board = NSPasteboard.general
        let saved = snapshot(of: board)
        board.clearContents()
        guard board.setString(text, forType: .string) else {
            restore(saved, to: board)
            return .failed
        }
        guard postCommandV() else {
            restore(saved, to: board)
            return .failed
        }

        restoreGeneration += 1
        let generation = restoreGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard generation == restoreGeneration else { return }
            restore(saved, to: .general)
        }
        return .pasted
    }

    /// Menu clicks can leave Kept focused. Activate the front regular app
    /// before a manual insert so Command-V lands in the app the user was in.
    static func focusForeignAppIfNeeded() async {
        let ours = Bundle.main.bundleIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != ours {
            return
        }
        guard let other = frontRegularApp(excluding: ours) else { return }
        other.activate()
        try? await Task.sleep(for: .milliseconds(120))
    }

    /// Some apps (Electron, Chromium) do not expose the selected text to
    /// Accessibility. Copy it instead, then put the pasteboard back.
    static func copySelection() async -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let board = NSPasteboard.general
        let saved = snapshot(of: board)
        let before = board.changeCount
        guard postCommand(0x08) else { return nil }
        var copied: String?
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(25))
            if board.changeCount != before {
                copied = board.string(forType: .string)
                break
            }
        }
        if board.changeCount != before {
            restore(saved, to: board)
        }
        return copied
    }

    /// 0x09 is kVK_ANSI_V.
    private static func postCommandV() -> Bool {
        postCommand(0x09)
    }

    /// Flags are set to Command alone: the live Right Option and Right Command
    /// would otherwise ride along on the posted key.
    private static func postCommand(_ key: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    /// A typed space. Paste trimming drops a trailing space, so the separator
    /// between takes cannot live only in the pasteboard string. Flags are cleared:
    /// the source copies live modifier state, and a Command left from the paste
    /// turns this into Command-Space, which opens Spotlight.
    static func typeSpace() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: false) else {
            return false
        }
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func snapshot(of board: NSPasteboard) -> Snapshot {
        let items = (board.pasteboardItems ?? []).map { item in
            var entries: [(String, Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    entries.append((type.rawValue, data))
                }
            }
            return Snapshot.Item(entries: entries)
        }
        return Snapshot(items: items)
    }

    private static func restore(_ snapshot: Snapshot, to board: NSPasteboard) {
        board.clearContents()
        let items: [NSPasteboardItem] = snapshot.items.compactMap { saved in
            guard !saved.entries.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (raw, data) in saved.entries {
                item.setData(data, forType: NSPasteboard.PasteboardType(raw))
            }
            return item
        }
        if !items.isEmpty {
            board.writeObjects(items)
        }
    }

    private static func frontRegularApp(excluding bundleID: String?) -> NSRunningApplication? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for window in windows {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            guard let pid = ownerPID(window) else { continue }
            guard let app = NSRunningApplication(processIdentifier: pid) else { continue }
            if app.bundleIdentifier == bundleID { continue }
            if app.activationPolicy != .regular { continue }
            return app
        }
        return nil
    }

    private static func ownerPID(_ window: [String: Any]) -> pid_t? {
        if let pid = window[kCGWindowOwnerPID as String] as? pid_t { return pid }
        if let pid = window[kCGWindowOwnerPID as String] as? Int { return pid_t(pid) }
        return nil
    }
}
