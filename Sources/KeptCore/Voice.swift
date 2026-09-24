import Foundation

public enum TalkingStyle: String, Codable, CaseIterable, Sendable {
    case spoken
    case casual
    case precise

    public var title: String {
        switch self {
        case .spoken: "As spoken"
        case .casual: "Casual"
        case .precise: "Precise"
        }
    }

    public var instruction: String {
        switch self {
        case .spoken:
            "Keep their wording. Fix punctuation, capitalization, and lists. Do not restyle the voice."
        case .casual:
            "Write it the way they would text a friend. Contractions, short sentences, warm. Do not drop words they said."
        case .precise:
            "Write clean professional prose. Tighten the phrasing. Do not add facts they did not say."
        }
    }
}

public struct VoiceMemory: Codable, Equatable, Sendable {
    public var style: TalkingStyle
    public var words: [String]

    public init(style: TalkingStyle = .spoken, words: [String] = []) {
        self.style = style
        self.words = words
    }
}
