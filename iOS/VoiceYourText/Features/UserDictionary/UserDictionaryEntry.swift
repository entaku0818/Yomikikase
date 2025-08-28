import Foundation

struct UserDictionaryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let word: String
    let reading: String
    let createdAt: Date
    
    init(id: UUID = UUID(), word: String, reading: String, createdAt: Date = Date()) {
        self.id = id
        self.word = word
        self.reading = reading
        self.createdAt = createdAt
    }
} 