import Foundation

enum TextInputDraft {
    static func hasReadableText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Explicit paste never replaces an existing draft or reads the clipboard in the background.
    static func appending(_ values: [String], to draft: String) -> String {
        let pasted = values.filter { hasReadableText($0) }.joined(separator: "\n")
        guard !pasted.isEmpty else {
            return draft
        }
        let separator = draft.isEmpty || draft.hasSuffix("\n") ? "" : "\n"
        return draft + separator + pasted
    }
}
