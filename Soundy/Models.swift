import Foundation

/// A track as the Soundy backend returns it (same JSON as the PC and Android apps use).
struct Track: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var img: String
    var url: String
    var duration: Int
    var source: String

    enum CodingKeys: String, CodingKey { case id, title, artist, album, img, url, duration, source }

    init(id: String, title: String, artist: String, album: String = "", img: String = "", url: String = "", duration: Int = 0, source: String = "") {
        self.id = id; self.title = title; self.artist = artist; self.album = album
        self.img = img; self.url = url; self.duration = duration; self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        album = (try? c.decode(String.self, forKey: .album)) ?? ""
        img = (try? c.decode(String.self, forKey: .img)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        if let d = try? c.decode(Int.self, forKey: .duration) { duration = d }
        else if let d = try? c.decode(Double.self, forKey: .duration) { duration = Int(d) }
        else { duration = 0 }
        source = (try? c.decode(String.self, forKey: .source)) ?? ""
    }

    var coverURL: URL? { img.isEmpty ? nil : URL(string: img) }

    /// Playable URL for iOS: AVPlayer has no WebM/Opus, so ask the backend for AAC (m4a).
    var streamURL: URL? {
        var s = url
        if s.hasPrefix("/") { s = API.base.absoluteString + s }
        guard var comps = URLComponents(string: s) else { return nil }
        var items = comps.queryItems ?? []
        if !items.contains(where: { $0.name == "fmt" }) { items.append(URLQueryItem(name: "fmt", value: "m4a")) }
        comps.queryItems = items
        return comps.url
    }

    var durationText: String {
        guard duration > 0 else { return "" }
        return String(format: "%d:%02d", duration / 60, duration % 60)
    }

    /// "first artist|title", normalised — to spot the same song from different sources.
    var matchKey: String {
        let first = artist.split(separator: ",").first.map(String.init) ?? artist
        return Track.norm(first) + "|" + Track.norm(title)
    }

    static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct LyricLine: Hashable {
    let time: Double   // seconds
    let text: String
}

enum LRC {
    /// Parses "[mm:ss.xx]text" lines; blank lines dropped, sorted by time.
    static func parse(_ lrc: String) -> [LyricLine] {
        var out: [LyricLine] = []
        let tag = try! NSRegularExpression(pattern: "\\[(\\d{1,2}):(\\d{2})(?:[.:](\\d{1,3}))?\\]")
        for raw in lrc.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let matches = tag.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let text = ns.substring(from: last.range.location + last.range.length).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            for m in matches {
                let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var frac = 0.0
                if m.range(at: 3).location != NSNotFound {
                    let f = ns.substring(with: m.range(at: 3))
                    frac = (Double(f) ?? 0) / pow(10, Double(f.count))
                }
                out.append(LyricLine(time: min * 60 + sec + frac, text: text))
            }
        }
        return out.sorted { $0.time < $1.time }
    }
}
