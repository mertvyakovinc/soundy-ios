import SwiftUI

struct MiniPlayer: View {
    @EnvironmentObject var player: Player
    @Binding var showPlayer: Bool

    var body: some View {
        if let t = player.current {
            VStack(spacing: 0) {
                if let err = player.errorText {
                    Text(err).font(.caption).foregroundStyle(Theme.dim).padding(.vertical, 4)
                }
                HStack(spacing: 12) {
                    Cover(url: t.coverURL, size: 44, radius: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(t.artist).font(.caption).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title3).frame(width: 40, height: 44)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.11))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke))
                )
                .overlay(alignment: .bottom) {
                    GeometryReader { g in
                        Capsule().fill(.white)
                            .frame(width: player.duration > 0 ? g.size.width * min(1, player.position / player.duration) : 0, height: 2)
                    }
                    .frame(height: 2).padding(.horizontal, 16)
                }
                .contentShape(Rectangle())
                .onTapGesture { showPlayer = true }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.bottom, 6)
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    @State private var showLyrics = false
    @State private var lyrics: [LyricLine] = []
    @State private var lyricsFor = ""
    @State private var scrubbing: Double?

    var body: some View {
        VStack(spacing: 22) {
            if let t = player.current {
                if showLyrics && !lyrics.isEmpty {
                    LyricsColumn(lines: lyrics, position: player.position) { player.seek(to: $0) }
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 8)
                    Cover(url: t.coverURL, size: 320, radius: 22)
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    Spacer(minLength: 8)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.title).font(.title3.bold()).lineLimit(1)
                        Text(t.artist).font(.body).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer()
                    Button { library.toggleLike(t) } label: {
                        Image(systemName: library.isLiked(t) ? "heart.fill" : "heart").font(.title2)
                    }
                }

                VStack(spacing: 6) {
                    Slider(value: Binding(get: { scrubbing ?? player.position },
                                          set: { scrubbing = $0 }),
                           in: 0...max(player.duration, 1),
                           onEditingChanged: { editing in
                               if !editing, let s = scrubbing { player.seek(to: s); scrubbing = nil }
                           })
                    HStack {
                        Text(fmt(scrubbing ?? player.position))
                        Spacer()
                        Text(fmt(player.duration))
                    }.font(.caption.monospacedDigit()).foregroundStyle(Theme.dim)
                }

                HStack {
                    Button { showLyrics.toggle() } label: {
                        Image(systemName: "quote.bubble\(showLyrics ? ".fill" : "")").font(.title3)
                            .foregroundStyle(lyrics.isEmpty ? Theme.faint : .white)
                    }.disabled(lyrics.isEmpty)
                    Spacer()
                    Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title) }
                    Spacer()
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 68))
                    }
                    Spacer()
                    Button { player.next() } label: { Image(systemName: "forward.fill").font(.title) }
                    Spacer()
                    Image(systemName: "quote.bubble").font(.title3).hidden()
                }
                .padding(.bottom, 8)
            } else {
                EmptyHint(text: "Ничего не играет")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
        .background(Theme.bg.ignoresSafeArea())
        .task(id: player.current?.id) { await loadLyrics() }
    }

    private func loadLyrics() async {
        guard let t = player.current, lyricsFor != t.id else { return }
        lyricsFor = t.id
        lyrics = []
        let found = await API.lyrics(for: t)
        if player.current?.id == t.id { lyrics = found }
    }

    private func fmt(_ s: Double) -> String {
        guard s.isFinite, s > 0 else { return "0:00" }
        let i = Int(s)
        return String(format: "%d:%02d", i / 60, i % 60)
    }
}

/// Apple-Music-style lyrics: the current line big and bright, neighbours dimmer, smooth scroll,
/// tap a line to jump there.
struct LyricsColumn: View {
    let lines: [LyricLine]
    let position: Double
    let seek: (Double) -> Void

    private var current: Int {
        var idx = -1
        for (i, l) in lines.enumerated() { if l.time <= position + 0.15 { idx = i } else { break } }
        return idx
    }

    var body: some View {
        let cur = current
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 120)
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                        let dist = cur < 0 ? i + 1 : abs(i - cur)
                        Text(l.text)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(opacity(dist, past: cur >= 0 && i < cur))
                            .scaleEffect(dist == 0 ? 1 : 0.94, anchor: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(i)
                            .onTapGesture { seek(l.time) }
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cur)
                    }
                    Color.clear.frame(height: 220)
                }
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                         .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .onChange(of: cur) { _, c in
                guard c >= 0 else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { proxy.scrollTo(c, anchor: UnitPoint(x: 0, y: 0.35)) }
            }
            .onAppear { if cur >= 0 { proxy.scrollTo(cur, anchor: UnitPoint(x: 0, y: 0.35)) } }
        }
    }

    private func opacity(_ dist: Int, past: Bool) -> Double {
        let base: Double
        switch dist {
        case 0: base = 1
        case 1: base = 0.55
        case 2: base = 0.38
        case 3: base = 0.26
        default: base = 0.16
        }
        return past ? base * 0.8 : base
    }
}
