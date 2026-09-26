import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import KeptCore

enum CaretInsert: Equatable {
    case location(Int)
    case selectionCouldNotCollapse
    case unavailable
}

enum FocusedField {
    static func trusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func caretForInsert() -> CaretInsert {
        guard trusted(), let element = element(), var range = selectedRange(of: element) else {
            return .unavailable
        }
        if range.length > 0 {
            range.location += range.length
            range.length = 0
            guard setSelectedRange(range, on: element) else { return .selectionCouldNotCollapse }
        }
        return .location(range.location)
    }

    /// The character before the caret, when the focused field exposes it.
    static func joinEdge() -> FieldJoin {
        guard trusted(), let element = element(), let range = selectedRange(of: element) else {
            return .unknown
        }
        let at = range.location + range.length
        if at == 0 { return .separated }
        guard let text = string(CFRange(location: at - 1, length: 1), on: element), let character = text.first else {
            return .unknown
        }
        return character.isWhitespace ? .separated : .needsSpace
    }

    static func select(location: Int, length: Int) -> Bool {
        guard let element = element() else { return false }
        return setSelectedRange(CFRange(location: location, length: length), on: element)
    }

    static func text(location: Int, length: Int) -> String? {
        guard location >= 0, length > 0, let element = element() else { return nil }
        return string(CFRange(location: location, length: length), on: element)
    }

    static func selectedText() -> String? {
        selectionRead().text
    }

    /// The selection, plus which step failed when there is none. The log gets
    /// the step and a length, never the selected words.
    struct SelectionRead {
        var text: String?
        var app: String
        var outcome: String
    }

    static func selectionRead() -> SelectionRead {
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let (focused, found) = focusedElement()
        guard let focused else {
            return SelectionRead(text: nil, app: app, outcome: "no focused element (AX \(found.rawValue))")
        }
        var value: CFTypeRef?
        let read = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &value)
        guard read == .success else {
            return SelectionRead(text: nil, app: app, outcome: "selected text unreadable (AX \(read.rawValue))")
        }
        let text = value as? String
        return SelectionRead(text: text, app: app, outcome: "\(text?.count ?? 0) chars")
    }

    static func deleteSelection() -> Bool {
        guard let element = element() else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, "" as CFString) == .success
    }

    /// Accessibility bounds of the insertion caret. Nil when the focused app
    /// does not expose a selection range. Callers must not invent a position.
    static func insertionBounds() -> CGRect? {
        guard trusted(), let element = element(), let range = selectedRange(of: element) else { return nil }
        let at = range.location + range.length
        if let rect = bounds(CFRange(location: at, length: 0), on: element), usable(rect) {
            return rect
        }
        if at > 0, let rect = bounds(CFRange(location: at - 1, length: 1), on: element), usable(rect) {
            return CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
        }
        if let rect = bounds(CFRange(location: range.location, length: 1), on: element), usable(rect) {
            return CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
        }
        return nil
    }

    private static func element() -> AXUIElement? {
        focusedElement().element
    }

    /// Electron and Chromium apps build no accessibility tree until a client
    /// asks for one, so the system-wide query answers -25212 (no value) and a
    /// selection there reads as none. Ask the frontmost app itself, with the
    /// tree switched on.
    private static func focusedElement() -> (element: AXUIElement?, error: AXError) {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let found = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value)
        if found == .success, let value { return ((value as! AXUIElement), found) }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return (nil, found) }
        let app = AXUIElementCreateApplication(pid)
        enableTree(app)
        var appValue: CFTypeRef?
        let appFound = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &appValue)
        guard appFound == .success, let appValue else { return (nil, appFound) }
        return ((appValue as! AXUIElement), appFound)
    }

    /// Call when an app comes to the front, so its tree is built before a hold.
    static func enableTree(pid: pid_t) {
        enableTree(AXUIElementCreateApplication(pid))
    }

    private static func enableTree(_ app: AXUIElement) {
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    private static func selectedRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value else { return nil }
        return decodeRange(value)
    }

    private static func string(_ range: CFRange, on element: AXUIElement) -> String? {
        var copy = range
        guard let axRange = AXValueCreate(.cfRange, &copy) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            axRange,
            &value
        ) == .success, let value else { return nil }
        return value as? String
    }

    private static func setSelectedRange(_ range: CFRange, on element: AXUIElement) -> Bool {
        var copy = range
        guard let value = AXValueCreate(.cfRange, &copy) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }

    private static func bounds(_ range: CFRange, on element: AXUIElement) -> CGRect? {
        var copy = range
        guard let axRange = AXValueCreate(.cfRange, &copy) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            axRange,
            &value
        ) == .success, let value else { return nil }
        return decodeRect(value)
    }

    private static func decodeRange(_ value: CFTypeRef) -> CFRange? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func decodeRect(_ value: CFTypeRef) -> CGRect? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func usable(_ rect: CGRect) -> Bool {
        rect.height > 1 || rect.width > 1
    }
}
