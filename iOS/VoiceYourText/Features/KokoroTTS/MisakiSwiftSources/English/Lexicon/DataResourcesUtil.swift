import Foundation

final class DataResourcesUtil {
    private init() {}
    
    static func loadGold(british: Bool) -> [String: Any] {
        loadLexicon(named: KokoroBundleResource.gold(british: british))
    }

    static func loadSilver(british: Bool) -> [String: Any] {
        loadLexicon(named: KokoroBundleResource.silver(british: british))
    }

    private static func loadLexicon(named filename: String) -> [String: Any] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            return [:]
        }
        return MisakiLexicon.parse(try? Data(contentsOf: url))
    }
}
