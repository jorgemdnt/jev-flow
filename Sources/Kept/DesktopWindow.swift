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
    private var liveHost: NSHostingView<LiveCard>?
    private let liveModel = LiveCardModel()
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

    @objc private func cancelLive() {
        session.cancelHold()
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
            _ = self.session.livePreview
            _ = self.session.liveCommitted
            _ = self.session.liveTail
            _ = self.session.microphoneName
            _ = self.session.editSubject
            _ = self.session.noticeTitle
            _ = self.session.noticeBody
            self.applyLive(self.session.livePhase)
        } onChange: {
            Task { @MainActor in self.watch() }
        }
    }

    private func applyLive(_ phase: LivePhase) {
        let mic = session.microphoneName
        let live = phase != .idle
        statusItem?.button?.image = optionStatusImage(live: live)
        if live {
            statusItem?.menu = nil
            statusItem?.button?.target = self
            statusItem?.button?.action = #selector(cancelLive)
            showLive()
            liveModel.update(
                committed: session.liveCommitted,
                tail: session.liveTail,
                phase: phase,
                mic: mic,
                subject: session.editSubject,
                kind: session.editKind,
                noticeTitle: session.noticeTitle,
                noticeBody: session.noticeBody
            )
            liveHost?.rootView = LiveCard(model: liveModel)
        } else {
            hideLive()
            statusItem?.button?.action = nil
            statusItem?.menu = menu
        }
    }

    private func showLive() {
        let panel = ensureLive()
        guard let button = statusItem?.button, let window = button.window else { return }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = Self.liveSize(phase: session.livePhase, spoken: spokenLine, selection: session.editSubject, noticeTitle: session.noticeTitle, noticeBody: session.noticeBody)
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
        let host = NSHostingView(rootView: LiveCard(model: liveModel))
        // LiveCardMetrics sets the panel frame. Default sizing options push the card's
        // unbounded SwiftUI height onto the panel's min size and ratchet it taller each update.
        host.sizingOptions = []
        liveHost = host
        let panel = LiveCardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.onClick = { [weak self] in self?.cancelLive() }
        panel.contentView = host
        host.autoresizingMask = [.width, .height]
        livePanel = panel
        return panel
    }

    private var spokenLine: String {
        let committed = session.liveCommitted
        let tail = session.liveTail
        if committed.isEmpty { return tail }
        if tail.isEmpty { return committed }
        return committed + " " + tail
    }

    static func liveSize(phase: LivePhase, spoken: String, selection: String, noticeTitle: String, noticeBody: String) -> NSSize {
        switch phase {
        case .editing:
            LiveCardMetrics.edit(selection: selection, instruction: spoken)
        case .notice:
            LiveCardMetrics.notice(title: noticeTitle, body: noticeBody)
        default:
            LiveCardMetrics.speech(spoken)
        }
    }

    private var menuStatus: String {
        if session.livePhase == .listening || session.livePhase == .locked { return "Listening" }
        if session.livePhase == .notice { return session.status }
        if session.livePhase == .editing { return "Edit" }
        if session.livePhase == .transcribing { return "Transcribing" }
        if session.livePhase == .cleaning { return "Formatting" }
        if session.status == "Hold Right Option to talk" { return "Ready" }
        return session.status
    }

    private var menuDot: NSColor {
        switch session.livePhase {
        case .listening, .locked: .systemRed
        case .editing: .systemBlue
        case .notice: .systemRed
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

private final class LiveCardPanel: NSPanel {
    var onClick: () -> Void = {}
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func mouseDown(with event: NSEvent) {
        onClick()
    }
}

@MainActor
private final class LiveCardModel: ObservableObject {
    @Published var committed = ""
    @Published var tail = ""
    @Published var phase = LivePhase.idle
    @Published var mic = ""

    @Published var noticeTitle = ""
    @Published var noticeBody = ""
    @Published var subject = ""
    @Published var kind = ""

    func update(committed: String, tail: String, phase: LivePhase, mic: String, subject: String, kind: String, noticeTitle: String, noticeBody: String) {
        let textChanged = committed != self.committed || tail != self.tail || subject != self.subject || noticeTitle != self.noticeTitle || noticeBody != self.noticeBody
        self.phase = phase
        self.mic = mic
        self.kind = kind
        self.noticeTitle = noticeTitle
        self.noticeBody = noticeBody
        guard textChanged else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            self.committed = committed
            self.tail = tail
            self.subject = subject
        }
    }
}

private struct LiveCard: View {
    @ObservedObject var model: LiveCardModel

    var body: some View {
        Group {
            if model.phase == .notice {
                NoticeCard(title: model.noticeTitle, message: model.noticeBody)
            } else if model.phase == .editing {
                EditCard(model: model)
            } else {
                SpeechCard(model: model)
            }
        }
    }
}

private struct NoticeCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            LucideMark(icon: .alert, size: 16, color: .red)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("esc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct EditCard: View {
    @ObservedObject var model: LiveCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                LucideMark(icon: .pencil, size: 12, color: .secondary)
                Text("Change")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(model.mic.isEmpty ? InputDevices.name(uid: MicStore.savedUID()) : model.mic)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text("release")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.kind.isEmpty ? "Text" : model.kind)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(model.subject.isEmpty ? "Nothing selected" : model.subject)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .truncationMode(.head)
                    .lineLimit(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            instruction
                .font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.7), lineWidth: 1)
        )
    }

    private var instruction: Text {
        let spoken = model.committed
        let tail = model.tail
        if spoken.isEmpty, tail.isEmpty {
            return Text("Say what to change")
                .foregroundStyle(.tertiary)
        }
        let committed = Text(spoken).foregroundStyle(.primary)
        let open = Text(tail.isEmpty ? "" : (spoken.isEmpty ? tail : " " + tail)).foregroundStyle(.secondary)
        let mark = Text(" ▍").foregroundStyle(.tertiary)
        return committed + open + mark
    }
}

private struct SpeechCard: View {
    @ObservedObject var model: LiveCardModel

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
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            line
                .font(.system(size: 15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
                .animation(.easeOut(duration: 0.16), value: model.committed)
                .animation(.easeOut(duration: 0.16), value: model.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KeptColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var line: Text {
        let committed = model.committed
        let tail = model.tail
        let spoken = Text(committed.isEmpty ? "" : committed)
            .foregroundStyle(.primary)
        let open = Text(tail.isEmpty ? "" : (committed.isEmpty ? tail : " " + tail))
            .foregroundStyle(.secondary)
        let mark = Text(tail.isEmpty && committed.isEmpty ? "…" : " ▍")
            .foregroundStyle(.tertiary)
        return spoken + open + mark
    }

    private var hint: String {
        switch model.phase {
        case .locked: "tap"
        case .editing: "say the change"
        case .notice: "esc"
        default: "esc"
        }
    }

    private var mic: String {
        model.mic.isEmpty ? InputDevices.name(uid: MicStore.savedUID()) : model.mic
    }

    private var caption: String {
        switch model.phase {
        case .listening: "Listening"
        case .locked: "Locked"
        case .editing: "Edit"
        case .notice: "Edit failed"
        case .transcribing: "Transcribing"
        case .cleaning: "Formatting"
        case .idle: "Ready"
        }
    }
}

enum LiveCardMetrics {
    static let width: CGFloat = 320
    static let maxBody: CGFloat = 180

    static func speech(_ text: String) -> NSSize {
        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let sample = text.isEmpty ? "…" : text
        let wrapped = box(sample, font: font, width: width - 24)
        let body = min(maxBody, max(22, wrapped.height))
        return NSSize(width: width, height: 44 + body)
    }

    static func edit(selection: String, instruction: String) -> NSSize {
        let quote = NSFont.systemFont(ofSize: 12)
        let spoken = NSFont.systemFont(ofSize: 14, weight: .medium)
        let instructionText = instruction.isEmpty ? "Say what to change" : instruction
        let selectionHeight = min(72, max(18, box(selection.isEmpty ? " " : selection, font: quote, width: width - 40).height))
        let instructionHeight = min(maxBody, max(22, box(instructionText, font: spoken, width: width - 24).height))
        return NSSize(width: width, height: 36 + selectionHeight + instructionHeight + 28)
    }

    static func notice(title: String, body: String) -> NSSize {
        let font = NSFont.systemFont(ofSize: 12)
        let wrapped = box(body, font: font, width: width - 56)
        let height = min(120, max(64, 36 + wrapped.height))
        return NSSize(width: width, height: height)
    }

    private static func box(_ text: String, font: NSFont, width: CGFloat) -> CGSize {
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: 8_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

