import Foundation

/// Likes and listening history, stored on the phone.
@MainActor
final class Library: ObservableObject {
    static let shared = Library()

    @Published private(set) var liked: [Track] = []
    @Published private(set) var history: [Track] = []

    private let likedKey = "soundy.liked"
    private let historyKey = "soundy.history"
    private let historyLimit = 200

    private init() {
        liked = load(likedKey)
        history = load(historyKey)
    }

    func isLiked(_ t: Track) -> Bool { liked.contains { $0.matchKey == t.matchKey } }

    func toggleLike(_ t: Track) {
        if isLiked(t) { liked.removeAll { $0.matchKey == t.matchKey } }
        else { liked.insert(t, at: 0) }
        save(liked, likedKey)
    }

    func addToHistory(_ t: Track) {
        history.removeAll { $0.matchKey == t.matchKey }
        history.insert(t, at: 0)
        if history.count > historyLimit { history.removeLast(history.count - historyLimit) }
        save(history, historyKey)
    }

    func clearHistory() {
        history = []
        save(history, historyKey)
    }

    private func load(_ key: String) -> [Track] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
    }

    private func save(_ list: [Track], _ key: String) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }
}
