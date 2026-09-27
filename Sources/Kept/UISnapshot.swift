import AppKit
import KeptCore
import SwiftUI

/// Deterministic UI captures without touching saved takes or the user's dictionary.
@MainActor
enum UISnapshot {
    static func save(in directory: String) -> Bool {
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        do { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        catch { return false }

        let store = TakeStore(directory: root.appendingPathComponent("fixture-takes"))
        let session = Session(store: store, startCapture: false)
        guard session.takes.isEmpty, session.livePhase == .idle, !session.recording else { return false }
        let fixtures: [Take] = [
            Take(id: UUID(), wavPath: "", rawTranscript: "Ship the update on Friday, not Monday.", durationSeconds: 4.2, insertedText: "Ship the update on Friday, not Monday."),
            Take(id: UUID(), wavPath: "", rawTranscript: "Draft the release note before the review.", durationSeconds: 3.8),
        ]
        session.takes = fixtures
        session.voice.words = ["CodeRabbit", "@felipe.menezes", "Artie", "auth"]
        let pages = KeptPages()
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            for (page, name) in [(KeptPage.history, "history"), (.dictionary, "dictionary"), (.settings, "settings")] {
                pages.page = page
                guard capture(KeptWindow(session: session, pages: pages), size: NSSize(width: 860, height: 740), dark: dark, to: root.appendingPathComponent("\(name)-\(suffix).png")) else { return false }
            }
            guard capture(KeptWindow(session: session, pages: pages), size: NSSize(width: 860, height: 1080), dark: dark, to: root.appendingPathComponent("settings-full-\(suffix).png")) else { return false }
            pages.page = .history
            session.takes = []
            guard capture(KeptWindow(session: session, pages: pages), size: NSSize(width: 860, height: 740), dark: dark, to: root.appendingPathComponent("history-empty-\(suffix).png")) else { return false }
            session.takes = fixtures
            guard capture(LanguageOnboarding(store: LanguageStore.shared, onDone: {}), size: NSSize(width: 440, height: 570), dark: dark, to: root.appendingPathComponent("onboarding-\(suffix).png")) else { return false }
        }
        return true
    }

    static func capture<V: View>(_ view: V, size: NSSize, dark: Bool, to url: URL) -> Bool {
        let rect = NSRect(origin: .zero, size: size)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = rect
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do { try data.write(to: url); return true }
        catch { return false }
    }
}
