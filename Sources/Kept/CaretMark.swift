import AppKit

@MainActor
final class CaretMark {
    var onNote: (String) -> Void = { _ in }

    private var panel: NSPanel?
    private var timer: Timer?
    private var shown = false

    func show() {
        ensurePanel()
        shown = true
        if timer == nil {
            let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tick()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        tick()
    }

    func hide() {
        shown = false
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        onNote("")
    }

    private func tick() {
        guard shown else { return }
        guard FocusedField.trusted() else {
            panel?.orderOut(nil)
            onNote("")
            return
        }
        guard let ax = FocusedField.insertionBounds() else {
            panel?.orderOut(nil)
            onNote(Session.caretMarkUnavailable)
            return
        }
        let frame = Self.windowFrame(fromAX: ax)
        guard let panel else { return }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        onNote("")
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 12, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let view = CaretMarkView(frame: panel.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
        self.panel = panel
    }

    /// Accessibility bounds are top-left on some systems and AppKit on others.
    /// Use whichever point lands on a screen. Never fall back to the mouse.
    static func windowFrame(fromAX rect: CGRect) -> CGRect {
        let flipped = flip(rect)
        let source = screenContains(flipped) || !screenContains(rect) ? flipped : rect
        let height = max(source.height, 18) + 10
        return CGRect(x: source.minX - 6, y: source.minY, width: 12, height: height)
    }

    private static func flip(_ rect: CGRect) -> CGRect {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens[0]
        return CGRect(
            x: rect.origin.x,
            y: primary.frame.height - rect.origin.y - rect.height,
            width: max(rect.width, 1),
            height: rect.height
        )
    }

    private static func screenContains(_ rect: CGRect) -> Bool {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -40, dy: -40).contains(point) }
    }
}

private final class CaretMarkView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.setFill()
        let bar = NSRect(x: bounds.midX - 1.5, y: 0, width: 3, height: max(bounds.height - 10, 8))
        NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 4, y: bounds.height - 9, width: 8, height: 8)).fill()
    }
}
