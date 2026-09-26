import Foundation

/// Right Option gestures. A hold pastes on release. Two short taps lock the
/// mic on. One later tap stops that lock. A selection, or Right Command
/// already down, makes Right Option an edit of that selection, not a paste.
public struct CaptureGestures: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case idle
        case holding(downAt: Int)
        case armed(upAt: Int)
        case locked
        case editing
        case ignoringUp
    }

    public enum Effect: Equatable, Sendable {
        case none
        case startHold
        case startLock
        case startEdit
        case finish
        case dismissTap
        case finishEdit
        case startHoldAfterTap
    }

    public static let tap = 280
    public static let gap = 320

    public private(set) var mode = Mode.idle

    public init() {}

    public mutating func optionDown(at ms: Int, commandDown: Bool, selection: Bool = false) -> Effect {
        switch mode {
        case .ignoringUp:
            return .none
        case .locked:
            mode = .ignoringUp
            return .finish
        case .editing, .holding:
            return .none
        case .armed(let upAt):
            if ms - upAt > Self.gap {
                mode = .holding(downAt: ms)
                return .startHoldAfterTap
            }
            mode = .locked
            return .startLock
        case .idle:
            if commandDown || selection {
                mode = .editing
                return .startEdit
            }
            mode = .holding(downAt: ms)
            return .startHold
        }
    }

    public mutating func optionUp(at ms: Int) -> Effect {
        switch mode {
        case .ignoringUp:
            mode = .idle
            return .none
        case .holding(let downAt):
            if ms - downAt <= Self.tap {
                mode = .armed(upAt: ms)
                return .none
            }
            mode = .idle
            return .finish
        case .editing:
            mode = .idle
            return .finishEdit
        case .idle, .armed, .locked:
            return .none
        }
    }

    /// The take ended without a key-up. A key that is still down must not paste again.
    public mutating func endedWithoutKey() {
        switch mode {
        case .holding, .editing:
            mode = .ignoringUp
        default:
            mode = .idle
        }
    }

    public mutating func tick(at ms: Int) -> Effect {
        guard case .armed(let upAt) = mode, ms - upAt >= Self.gap else { return .none }
        mode = .idle
        return .dismissTap
    }
}

public enum HoldKeyCommand {
    public static let rightCommandDeviceBit: UInt64 = 0x10
    public static let commandBit: UInt64 = 0x0010_0000

    public static func rightCommandDown(flags: UInt64) -> Bool {
        let devices = flags & HoldKey.deviceModifierBits
        if devices != 0 {
            return (flags & rightCommandDeviceBit) != 0
        }
        return (flags & commandBit) != 0
    }
}

/// The edit chord asks a model to change text. The hold does not.
public enum EditPrompt {
    public static let system = """
    You edit a piece of text the user selected. The instruction was spoken and \
    transcribed, so it may contain recognition errors; read it for intent. Apply \
    it to the selected text and return only the edited selected text, with no \
    quotes, labels, or commentary. Never return the instruction itself. If the \
    instruction does not ask for a change you can make, return the selected text \
    unchanged.
    """

    public static func request(text: String, instruction: String) -> String {
        """
        <selected_text>
        \(text)
        </selected_text>

        <spoken_instruction>
        \(instruction)
        </spoken_instruction>

        Return the edited selected text only.
        """
    }

    public static func text(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            let cleaned = unwrap(content)
            if !cleaned.isEmpty { return cleaned }
        }
        guard let output = json["output"] as? [[String: Any]] else { return nil }
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content {
                guard part["type"] as? String == "output_text",
                      let text = part["text"] as? String else { continue }
                let cleaned = unwrap(text)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    static func unwrap(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value.drop(while: { $0 != "\n" }).dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasSuffix("```") {
                value = String(value.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return value
    }
}
