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
        guard let element = element() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
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
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
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
