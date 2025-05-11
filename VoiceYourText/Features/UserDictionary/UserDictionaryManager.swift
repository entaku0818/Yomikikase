import Foundation
import Dependencies

struct UserDictionaryClient {
    var entries: () -> [UserDictionaryEntry]
    var addEntry: (String, String) -> Void
    var removeEntry: (UUID) -> Void
    var getReading: (String) -> String?
}

extension UserDictionaryClient: DependencyKey {
    static let liveValue = Self(
        entries: {
            guard let data = UserDefaults.standard.data(forKey: "userDictionary"),
                  let entries = try? JSONDecoder().decode([UserDictionaryEntry].self, from: data) else {
                return []
            }
            return entries
        },
        addEntry: { word, reading in
            let entry = UserDictionaryEntry(word: word, reading: reading)
            var currentEntries = UserDefaults.standard.data(forKey: "userDictionary")
                .flatMap { try? JSONDecoder().decode([UserDictionaryEntry].self, from: $0) } ?? []
            currentEntries.append(entry)
            if let data = try? JSONEncoder().encode(currentEntries) {
                UserDefaults.standard.set(data, forKey: "userDictionary")
            }
        },
        removeEntry: { id in
            guard let data = UserDefaults.standard.data(forKey: "userDictionary"),
                  var entries = try? JSONDecoder().decode([UserDictionaryEntry].self, from: data) else {
                return
            }
            entries.removeAll { $0.id == id }
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: "userDictionary")
            }
        },
        getReading: { word in
            guard let data = UserDefaults.standard.data(forKey: "userDictionary"),
                  let entries = try? JSONDecoder().decode([UserDictionaryEntry].self, from: data) else {
                return nil
            }
            return entries.first { $0.word == word }?.reading
        },
    )
    
    static let testValue = Self(
        entries: { [] },
        addEntry: { _, _ in },
        removeEntry: { _ in },
        getReading: { _ in nil }
    )
}

extension DependencyValues {
    var userDictionary: UserDictionaryClient {
        get { self[UserDictionaryClient.self] }
        set { self[UserDictionaryClient.self] = newValue }
    }
} 
