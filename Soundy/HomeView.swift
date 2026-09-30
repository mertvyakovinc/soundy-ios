import SwiftUI

struct HomeView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    @State private var loadingWave = false
    @State private var trending: [Track] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                if !library.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "Недавно слушали")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(Array(library.history.prefix(20).enumerated()), id: \.offset) { i, t in
                                    Button { player.play(Array(library.history.prefix(20)), at: i) } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Cover(url: t.coverURL, size: 140, radius: 14)
                                            Text(t.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(Theme.text)
                                            Text(t.artist).font(.caption).lineLimit(1).foregroundStyle(Theme.dim)
                                        }.frame(width: 140)
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 20)
                        }
                        .padding(.horizontal, -20)
                    }
                }
                if !trending.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Сейчас в трендах")
                        ForEach(Array(trending.enumerated()), id: \.offset) { i, t in
                            TrackRow(track: t) { player.play(trending, at: i) }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { if trending.isEmpty { trending = await API.trending() } }
        .refreshable { trending = await API.trending() }
    }

    private var hero: some View {
        let playingWave = player.isWave && player.isPlaying
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if playingWave { Circle().fill(Color(red: 0.11, green: 0.73, blue: 0.33)).frame(width: 7, height: 7) }
                Text(playingWave ? "СЕЙЧАС ИГРАЕТ" : "ПЕРСОНАЛЬНЫЙ ПОТОК")
                    .font(.caption.weight(.bold)).kerning(1.4).foregroundStyle(Theme.dim)
            }
            Text("Моя волна").font(.system(size: 42, weight: .bold)).kerning(-1).foregroundStyle(Theme.text)
            Text(player.isWave ? "Подборка как станции SoundCloud — от твоих треков в похожие"
                 : "Бесконечный поток музыки под твой вкус")
                .font(.subheadline).foregroundStyle(Theme.dim)
            HStack(spacing: 12) {
                Button {
                    if player.isWave { player.togglePlay() } else { startWave() }
                } label: {
                    HStack(spacing: 10) {
                        if loadingWave { ProgressView().tint(.black) }
                        else { Image(systemName: playingWave ? "pause.fill" : "play.fill") }
                        Text(playingWave ? "Пауза" : (player.isWave ? "Продолжить" : "Слушать")).fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24).frame(height: 52)
                    .background(Capsule().fill(.white))
                }
                Button { startWave() } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                }
            }
            .padding(.top, 10)
        }
        .padding(.top, 12)
    }

    private func startWave() {
        guard !loadingWave else { return }
        loadingWave = true
        Task {
            let tracks = await Wave.build()
            loadingWave = false
            if !tracks.isEmpty { player.play(tracks, at: 0, wave: true) }
            else { player.errorText = "Волна не собралась — проверь интернет" }
        }
    }
}
