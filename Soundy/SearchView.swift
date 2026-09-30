import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: Player
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if searching && results.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
            } else if !query.isEmpty && results.isEmpty {
                EmptyHint(text: "Ничего не нашлось").listRowBackground(Color.clear)
            }
            ForEach(Array(results.enumerated()), id: \.offset) { i, t in
                TrackRow(track: t) { player.play(results, at: i) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Поиск")
        .searchable(text: $query, prompt: "Треки, артисты")
        .onChange(of: query) { _, q in runSearch(q) }
    }

    private func runSearch(_ q: String) {
        searchTask?.cancel()
        let text = q.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { results = []; searching = false; return }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)   // debounce typing
            guard !Task.isCancelled else { return }
            let found = await API.search(text)
            guard !Task.isCancelled else { return }
            results = found
            searching = false
        }
    }
}
