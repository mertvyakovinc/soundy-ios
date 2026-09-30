import SwiftUI

@main
struct SoundyApp: App {
    @StateObject private var player = Player.shared
    @StateObject private var library = Library.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
                .environmentObject(library)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: Library
    @State private var showPlayer = false

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("Главная", systemImage: "house.fill") }
            NavigationStack { SearchView() }
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
            NavigationStack { LibraryView() }
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("Коллекция", systemImage: "square.stack.fill") }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(player)
                .environmentObject(library)
                .presentationDragIndicator(.visible)
        }
    }
}

extension View {
    /// Mini player docked above the tab bar on every tab.
    func withMiniPlayer(showPlayer: Binding<Bool>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayer(showPlayer: showPlayer)
        }
    }
}
