import Foundation

/// The Soundy backend — same endpoints as the PC and Android apps.
enum API {
    static let base = URL(string: "https://soundy.space")!

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.httpAdditionalHeaders = ["User-Agent": "SoundyiOS/2.6"]
        return URLSession(configuration: cfg)
    }()

    private static func get(_ path: String, _ query: [String: String] = [:]) async throws -> Data {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        let (data, resp) = try await session.data(from: comps.url!)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct TracksBox: Decodable { let tracks: [Track]? }

    /// Accepts both a bare list and { tracks: [...] }.
    private static func decodeTracks(_ data: Data) -> [Track] {
        let dec = JSONDecoder()
        if let list = try? dec.decode([Track].self, from: data) { return list }
        if let box = try? dec.decode(TracksBox.self, from: data) { return box.tracks ?? [] }
        return []
    }

    static func search(_ q: String) async -> [Track] {
        guard let data = try? await get("/api/search", ["q": q]) else { return [] }
        return decodeTracks(data).filter { !$0.title.isEmpty && !$0.url.isEmpty }
    }

    static func trending() async -> [Track] {
        guard let data = try? await get("/api/trending") else { return [] }
        return decodeTracks(data).filter { !$0.url.isEmpty }
    }

    /// SoundCloud-style station from seed songs ("sc:123" ids and "Artist - Title" queries).
    static func station(ids: [String], queries: [String], limit: Int = 40) async -> [Track] {
        guard !ids.isEmpty || !queries.isEmpty else { return [] }
        let q = queries.map { $0.replacingOccurrences(of: ";;", with: " ") }.joined(separator: ";;")
        guard let data = try? await get("/api/station", ["ids": ids.joined(separator: ","), "q": q, "limit": String(limit)]) else { return [] }
        return decodeTracks(data).filter { !$0.url.isEmpty }
    }

    private struct LyricsDTO: Decodable { let syncedLyrics: String?; let plainLyrics: String? }

    /// Synced lyrics (the server prefers YouTube Music's own timed lyrics, length-checked).
    static func lyrics(for t: Track) async -> [LyricLine] {
        var q = ["artist": t.artist, "title": t.title, "id": t.id]
        if t.duration > 0 { q["duration"] = String(t.duration) }
        guard let data = try? await get("/api/lyrics", q),
              let dto = try? JSONDecoder().decode(LyricsDTO.self, from: data),
              let lrc = dto.syncedLyrics, !lrc.isEmpty else { return [] }
        return LRC.parse(lrc)
    }
}
