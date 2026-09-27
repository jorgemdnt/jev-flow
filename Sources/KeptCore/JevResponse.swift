import Foundation

/// Validate Jev's choice against the exact spans sent in that question.
/// A response is a judgment, not permission to invent transcript text.
public enum JevResponse {
    public enum Failure: Error {
        case invalidAnswers
    }

    public static func parse(
        _ data: Data,
        candidates: [String: (entry: String, spans: [String])],
        respell: [String: Respell.Candidate]
    ) throws -> JevJudgment {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["answers"] as? [String: Any],
              !answers.isEmpty else {
            throw Failure.invalidAnswers
        }
        let shape: SpokenShape
        if let answer = answers["shape"] as? [String: Any],
           let choice = answer["choice"] as? String,
           let confidence = answer["confidence"] as? Double,
           confidence >= SpeechFormat.minimumConfidence,
           let accepted = SpokenShape(rawValue: choice) {
            shape = accepted
        } else {
            shape = .prose
        }
        var replacements: [Replacement] = []
        for (id, candidate) in candidates {
            guard let answer = answers[id] as? [String: Any],
                  let choice = answer["choice"] as? String,
                  candidate.spans.contains(choice),
                  let confidence = answer["confidence"] as? Double,
                  confidence >= SpeechFormat.minimumConfidence else { continue }
            replacements.append(Replacement(span: choice, word: candidate.entry))
        }
        var respelled: [Respell.Candidate] = []
        for (id, candidate) in respell {
            guard let answer = answers[id] as? [String: Any],
                  let probabilities = answer["probabilities"] as? [String: Double],
                  let meant = probabilities["meant"],
                  meant >= Respell.minimumConfidence else { continue }
            respelled.append(candidate)
        }
        return JevJudgment(shape: shape, replacements: replacements, respell: respelled)
    }
}
