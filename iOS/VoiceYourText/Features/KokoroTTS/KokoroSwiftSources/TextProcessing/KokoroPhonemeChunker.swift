import Foundation

/// Splits Japanese phonemes after G2P so chunking cannot change kanji/number readings.
/// Tokenizer maps each Character to at most one token, so this is a conservative bound.
/// Kokoro recommends roughly 100–200 tokens; its hard input limit is 510.
enum KokoroPhonemeChunker {
    static let maximumLength = 200
    static let minimumLength = 20
    private static let sentenceEnds = Set<Character>(".!?…")
    private static let phraseEnds = Set<Character>(",;:—")
    private static let closingMarks = Set<Character>("\"'”’)]}」』")

    static func chunks(_ phonemes: String) -> [String] {
        let characters = Array(phonemes)
        var result: [String] = []
        var start = 0

        while characters.count - start > maximumLength {
            // Leave enough context in the final chunk, rather than a few isolated phonemes.
            let limit = min(start + maximumLength, characters.count - minimumLength)
            let sentenceEnd = boundary(in: characters, from: start, through: limit, sentenceOnly: true)
            let phraseEnd = boundary(in: characters, from: start, through: limit, sentenceOnly: false)
            // Without punctuation, balance the last pair instead of leaving a tiny tail.
            let fallback = start + min(maximumLength, (characters.count - start) / 2)
            let end = sentenceEnd ?? phraseEnd ?? fallback
            result.append(String(characters[start..<end]))
            start = end
        }
        if start < characters.count {
            result.append(String(characters[start...]))
        }
        return result
    }

    /// Shared by production inference and tests. A failure/cancellation never returns partial audio.
    static func synthesize(
        _ phonemes: String,
        generate: (String) throws -> [Float]
    ) throws -> [Float] {
        try Task.checkCancellation()
        var samples: [Float] = []
        for chunk in chunks(phonemes) {
            try Task.checkCancellation()
            samples.append(contentsOf: try generate(chunk))
        }
        try Task.checkCancellation()
        return samples
    }

    private static func boundary(
        in characters: [Character], from start: Int, through limit: Int, sentenceOnly: Bool
    ) -> Int? {
        var lastEnd: Int?
        for index in start..<limit {
            let character = characters[index]
            let matches = sentenceOnly
                ? sentenceEnds.contains(character)
                : phraseEnds.contains(character) || character.isWhitespace
            guard matches else { continue }
            var end = index + 1
            // Keep closing quotes, punctuation runs and their spaces with the preceding phrase.
            while end < characters.count,
                  sentenceEnds.contains(characters[end]) || closingMarks.contains(characters[end])
                    || characters[end].isWhitespace {
                end += 1
                if end > limit { break }
            }
            if end >= start + minimumLength, end <= limit {
                lastEnd = end
            }
        }
        return lastEnd
    }
}
