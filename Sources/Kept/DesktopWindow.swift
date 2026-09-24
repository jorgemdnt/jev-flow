import AppKit
import KeptCore
import SwiftUI

enum KeptPage: Hashable {
    case history
    case dictionary
    case style
    case settings
}

@MainActor
@Observable
final class KeptPages {
    var page: KeptPage = .history
}

@MainActor
final class KeptChrome: NSObject, NSMenuDelegate, NSWindowDelegate {
    let session: Session
    let pages = KeptPages()
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var onboarding: NSWindow?
    private var livePanel: NSPanel?
    private let menu = NSMenu()

    init(session: Session) {
        self.session = session
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = optionStatusImage(live: false)
        statusItem = item
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        TypeSafeKey.adoptEnvironmentKey()
        watch()
        if LanguageStore.shared.needsOnboarding {
            openOnboarding()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: menuStatus, action: nil, keyEquivalent: "")
        status.image = dot(menuDot)
        status.isEnabled = false
        menu.addItem(status)
        if !session.canInsert {
            let missing = NSMenuItem(title: "Accessibility required to insert", action: nil, keyEquivalent: "")
            missing.isEnabled = false
            menu.addItem(missing)
        }
        if !session.caretNote.isEmpty {
            let note = NSMenuItem(title: session.caretNote, action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
        }
        menu.addItem(.separator())
        menu.addItem(item("Open JevFlow", symbol: "macwindow", action: #selector(openHistory), key: "o"))
        menu.addItem(.separator())

        menu.addItem(item("Dictionary…", symbol: "character.book.closed", action: #selector(openDictionary), key: ""))
        menu.addItem(item("Settings…", symbol: "gearshape", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())

        if let held = session.takes.first(where: { session.refusesAutoInsert($0) && $0.insertedText == nil }) {
            let raw = item("Insert raw", symbol: "arrow.down.doc", action: #selector(insertRawItem(_:)), key: "")
            raw.representedObject = held.id
            menu.addItem(raw)
            menu.addItem(.separator())
        }

        menu.addItem(item("Quit JevFlow", symbol: "power", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, symbol name: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.image = symbol(name)
        return item
    }

    @objc private func openHistory() { open(.history) }
    @objc private func openDictionary() { open(.dictionary) }
    @objc private func openSettings() { open(.settings) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func insertRawItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        session.insertRaw(id)
    }

    private func open(_ page: KeptPage) {
        pages.page = page
        NSApp.setActivationPolicy(.regular)
        let window = ensureWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        if closed === onboarding { onboarding = nil }
        if closed === window { window = nil }
        if window == nil, onboarding == nil {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let host = NSHostingController(rootView: KeptWindow(session: session, pages: pages))
        let window = NSWindow(contentViewController: host)
        window.title = "JevFlow"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 860, height: 560))
        window.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.11, alpha: 1)
                : NSColor(calibratedRed: 0.965, green: 0.957, blue: 0.945, alpha: 1)
        })
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        return window
    }

    private func openOnboarding() {
        if onboarding != nil { return }
        let host = NSHostingController(rootView: LanguageOnboarding(store: LanguageStore.shared) { [weak self] in
            self?.onboarding?.close()
        })
        let panel = NSWindow(contentViewController: host)
        panel.title = "JevFlow"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.styleMask = [.titled, .closable, .fullSizeContentView]
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.delegate = self
        onboarding = panel
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func watch() {
        withObservationTracking {
            self.applyLive(self.session.livePhase)
        } onChange: {
            Task { @MainActor in self.watch() }
        }
    }

    private func applyLive(_ phase: LivePhase) {
        let live = phase != .idle
        statusItem?.button?.image = optionStatusImage(live: live)
        if live {
            statusItem?.menu = nil
            showLive()
        } else {
            hideLive()
            statusItem?.menu = menu
        }
    }

    private func showLive() {
        let panel = ensureLive()
        guard let button = statusItem?.button, let window = button.window else { return }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = NSSize(width: 288, height: 76)
        let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = rect.maxX - size.width
        if rect.midX < screen.midX { x = rect.minX }
        x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(
            NSRect(x: x, y: rect.minY - size.height - 8, width: size.width, height: size.height),
            display: true
        )
        panel.orderFrontRegardless()
    }

    private func hideLive() {
        livePanel?.orderOut(nil)
    }

    private func ensureLive() -> NSPanel {
        if let livePanel { return livePanel }
        let host = NSHostingView(rootView: LiveCard(session: session))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 288, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = host
        livePanel = panel
        return panel
    }

    private var menuStatus: String {
        if session.livePhase == .listening { return "Listening" }
        if session.livePhase == .transcribing { return "Transcribing" }
        if session.livePhase == .cleaning { return "Formatting" }
        if session.status == "Hold Right Option to talk" { return "Ready" }
        return session.status
    }

    private var menuDot: NSColor {
        switch session.livePhase {
        case .listening: .systemRed
        case .transcribing, .cleaning: .systemOrange
        case .idle: session.canInsert ? .systemGreen : .systemOrange
        }
    }

    private func optionStatusImage(live: Bool) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let box = rect.insetBy(dx: live ? 1.4 : 2.0, dy: live ? 1.4 : 2.0)
            func map(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: box.minX + x / 24 * box.width, y: box.minY + (24 - y) / 24 * box.height)
            }
            let zigzag = NSBezierPath()
            zigzag.move(to: map(3, 3))
            zigzag.line(to: map(9, 3))
            zigzag.line(to: map(15, 21))
            zigzag.line(to: map(21, 21))
            let bar = NSBezierPath()
            bar.move(to: map(14, 3))
            bar.line(to: map(21, 3))
            NSColor.black.setStroke()
            for path in [zigzag, bar] {
                path.lineWidth = live ? 2.15 : 1.65
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "JevFlow"
        return image
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    private func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 6, height: 6)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private struct LiveCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                LucideMark(icon: .option, size: 12, color: .secondary)
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(mic)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text(tail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 288, height: 76, alignment: .topLeading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var mic: String {
        session.microphoneName.isEmpty ? InputDevices.name(uid: MicStore.savedUID()) : session.microphoneName
    }

    private var tail: String {
        let text = session.livePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "…" }
        guard text.count > 120 else { return text }
        let start = text.index(text.endIndex, offsetBy: -120)
        let slice = text[start...]
        guard let space = slice.firstIndex(where: { $0.isWhitespace }) else { return String(slice) }
        let rest = slice[slice.index(after: space)...].trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? String(slice) : rest
    }

    private var caption: String {
        switch session.livePhase {
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .cleaning: "Formatting"
        case .idle: "Ready"
        }
    }
}

