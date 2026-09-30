import Foundation

/// "Моя волна": a SoundCloud-style station seeded with a few recent plays and likes
/// (same /api/station the PC and Android apps use). Trending as a start for a fresh profile.
enum Wave {
    @MainActor
    static func build() async -> [Track] {
        let lib = Library.shared
        let pool: [Track] = Array(Array(lib.history.prefix(12)).shuffled().prefix(3)) + Array(Array(lib.liked.prefix(15)).shuffled().prefix(3))
        var ids: [String] = []
        var queries: [String] = []
        var seen = Set<String>()
        for t in pool where !t.title.isEmpty {
            guard seen.insert(t.matchKey).inserted else { continue }
            if t.id.hasPrefix("sc:"), t.id.dropFirst(3).allSatisfy(\.isNumber) { ids.append(t.id) }
            else {
                let primary = t.artist.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? t.artist
                queries.append(primary.isEmpty ? t.title : "\(primary) - \(t.title)")
            }
        }

        let heard = Set(lib.history.prefix(60).map(\.matchKey))
        var tracks = await API.station(ids: ids, queries: queries)
        if tracks.count < 8 { tracks += await API.trending() }

        var out: [Track] = []
        var keys = Set<String>()
        for t in tracks where !heard.contains(t.matchKey) && keys.insert(t.matchKey).inserted {
            out.append(t)
        }
        return out
    }
}
