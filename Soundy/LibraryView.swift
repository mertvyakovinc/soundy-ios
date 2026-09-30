import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    @State private var tab = 0

    var body: some View {
        let list = tab == 0 ? library.liked : library.history
        List {
            Picker("", selection: $tab) {
                Text("Любимые").tag(0)
                Text("История").tag(1)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if list.isEmpty {
                EmptyHint(text: tab == 0 ? "Лайкни трек через «…», и он появится здесь" : "Здесь будет то, что ты слушал")
                    .listRowBackground(Color.clear)
            }
            ForEach(Array(list.enumerated()), id: \.offset) { i, t in
                TrackRow(track: t) { player.play(list, at: i) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Коллекция")
    }
}
