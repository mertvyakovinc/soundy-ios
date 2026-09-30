import SwiftUI

enum Theme {
    static let bg = Color.black
    static let text = Color.white
    static let dim = Color(white: 0.56)
    static let faint = Color(white: 0.36)
    static let glass = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.12)
}

struct Cover: View {
    let url: URL?
    var size: CGFloat
    var radius: CGFloat = 10

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let img): img.resizable().scaledToFill()
            default:
                ZStack {
                    Theme.glass
                    Image(systemName: "music.note").foregroundStyle(Theme.faint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct TrackRow: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    let track: Track
    let action: () -> Void

    var body: some View {
        let isCurrent = player.current?.matchKey == track.matchKey
        HStack(spacing: 14) {
            Cover(url: track.coverURL, size: 50, radius: 10)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55))
                        Image(systemName: player.isPlaying ? "waveform" : "pause.fill").foregroundStyle(.white)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.body.weight(.medium)).lineLimit(1)
                    .foregroundStyle(Theme.text)
                Text([track.artist, track.durationText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(Theme.dim).lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button(library.isLiked(track) ? "Убрать из любимых" : "Мне нравится",
                       systemImage: library.isLiked(track) ? "heart.slash" : "heart") { library.toggleLike(track) }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(Theme.dim).frame(width: 36, height: 44)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title2.bold()).foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 28)
    }
}
