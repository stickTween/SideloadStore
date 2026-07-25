import SwiftUI

@main
struct SideloadStoreApp: App {
    @StateObject private var store = SourceStore()
    @StateObject private var library = Library()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(library)
                .onOpenURL { url in library.importFile(url) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: SourceStore

    var body: some View {
        TabView {
            CatalogView()
                .tabItem { Label("Каталог", systemImage: "square.grid.2x2") }
            SourcesView()
                .tabItem { Label("Источники", systemImage: "antenna.radiowaves.left.and.right") }
            LibraryView()
                .tabItem { Label("Библиотека", systemImage: "tray.full") }
        }
        .task {
            if store.sources.isEmpty { await store.refresh() }
        }
    }
}
