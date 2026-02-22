import Foundation

struct HTMLTextExtractor {
    static func extract(from html: String) -> String {
        var text = html

        // Remove script blocks
        text = removeBlock(pattern: "<script[^>]*>[\\s\\S]*?</script>", from: text)

        // Remove style blocks
        text = removeBlock(pattern: "<style[^>]*>[\\s\\S]*?</style>", from: text)

        // Remove head block
        text = removeBlock(pattern: "<head[^>]*>[\\s\\S]*?</head>", from: text)

        // Replace block-level closing tags with newlines
        text = replacePattern(
            "<br\\s*/?>|</p>|</div>|</h[1-6]>|</li>|</tr>|</blockquote>|</article>|</section>",
            in: text,
            with: "\n"
        )

        // Remove all remaining HTML tags
        text = removeBlock(pattern: "<[^>]+>", from: text)

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Normalize whitespace
        text = normalizeWhitespace(text)

        return text
    }

    private static func removeBlock(pattern: String, from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func replacePattern(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Named entities
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "\u{2014}"),
            ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}"),
            ("&laquo;", "\u{00AB}"),
            ("&raquo;", "\u{00BB}"),
            ("&copy;", "\u{00A9}"),
            ("&reg;", "\u{00AE}"),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Hex numeric entities &#xNNN;
        while let range = result.range(of: "&#x[0-9a-fA-F]+;", options: .regularExpression) {
            let matched = String(result[range])
            let hexStr = String(matched.dropFirst(3).dropLast(1))
            if let codePoint = UInt32(hexStr, radix: 16),
               let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(scalar))
            } else {
                break
            }
        }

        // Decimal numeric entities &#NNN;
        while let range = result.range(of: "&#[0-9]+;", options: .regularExpression) {
            let matched = String(result[range])
            let decStr = String(matched.dropFirst(2).dropLast(1))
            if let codePoint = UInt32(decStr),
               let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(scalar))
            } else {
                break
            }
        }

        return result
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        var result = text

        // Replace tabs with spaces
        result = result.replacingOccurrences(of: "\t", with: " ")

        // Collapse multiple spaces into one
        if let regex = try? NSRegularExpression(pattern: " {2,}") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }

        // Collapse more than 2 consecutive newlines into 2
        if let regex = try? NSRegularExpression(pattern: "\n{3,}") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
