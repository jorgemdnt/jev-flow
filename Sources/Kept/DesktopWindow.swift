import AppKit
import KeptCore
import SwiftUI

@MainActor
final class KeptChrome: NSObject, NSMenuDelegate {
    let session: Session
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private let menu = NSMenu()

    init(session: Session) {
        self.session = session
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(click)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        menu.delegate = self
        watch()
        if UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true {
            show()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: session.status, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if !session.caretNote.isEmpty {
            let note = NSMenuItem(title: session.caretNote, action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
        }
        if !session.canInsert {
            let missing = NSMenuItem(title: Session.insertNeedsAccessibility, action: nil, keyEquivalent: "")
            missing.isEnabled = false
            menu.addItem(missing)
        }
        menu.addItem(.separator())
        let toggle = NSMenuItem(
            title: panel?.isVisible == true ? "Hide Window" : "Show Window",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func click() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popMenu()
        } else {
            toggleWindow()
        }
    }

    @objc private func toggleWindow() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func show() {
        let panel = ensurePanel()
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
    }

    private func hide() {
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    private func popMenu() {
        guard let button = statusItem?.button else { return }
        menuWillOpen(menu)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let host = NSHostingController(rootView: KeptDesktopView(session: session))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Kept"
        panel.contentViewController = host
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameAutosaveName("KeptDesktop")
        panel.isMovableByWindowBackground = false
        panel.center()
        self.panel = panel
        return panel
    }

    private func watch() {
        withObservationTracking {
            self.applyIcon(recording: session.recording)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.watch()
            }
        }
    }

    private func applyIcon(recording: Bool) {
        let name = recording ? "mic.fill" : "mic"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Kept")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    private static let visibleKey = "KeptWindowVisible"
}

struct KeptDesktopView: View {
    @Bindable var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.status)
                .font(.headline)
            if !session.caretNote.isEmpty, session.caretNote != session.status {
                Text(session.caretNote)
                    .foregroundStyle(.secondary)
            }
            if !session.canInsert, session.status != Session.insertNeedsAccessibility {
                Text(Session.insertNeedsAccessibility)
                    .foregroundStyle(.secondary)
            }
            labeled("Last raw", session.lastRawTranscript.isEmpty ? "No takes yet" : session.lastRawTranscript)
            labeled("Last inserted", session.lastInsertedText.isEmpty ? "Nothing inserted yet" : session.lastInsertedText)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if session.takes.isEmpty {
                        Text("No takes yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.takes) { take in
                        takeRow(take)
                        Divider()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 340, minHeight: 420)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func takeRow(_ take: Take) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(take.rawTranscript.isEmpty ? "(empty transcript)" : take.rawTranscript)
                .textSelection(.enabled)
            Text(String(format: "%.1f s", take.durationSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
            if session.refusesAutoInsert(take), take.insertedText == nil {
                Text(Session.keptNotPasted)
                Button("Insert raw") { session.insertRaw(take.id) }
            } else if let inserted = take.insertedText {
                Text(inserted)
                    .textSelection(.enabled)
            } else {
                if !session.keptText(take).isEmpty {
                    Text(session.keptText(take))
                        .textSelection(.enabled)
                }
                Button("Insert") { session.insertKept(take.id) }
            }
            Button("Dismiss") { session.dismiss(take.id) }
        }
    }
}
