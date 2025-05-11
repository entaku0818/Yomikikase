import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct DictionaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let entries: [UserDictionaryEntry]
    
    init(entries: [UserDictionaryEntry]) {
        self.entries = entries
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let entries = try? JSONDecoder().decode([UserDictionaryEntry].self, from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.entries = entries
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(entries)
        return FileWrapper(regularFileWithContents: data)
    }
} 