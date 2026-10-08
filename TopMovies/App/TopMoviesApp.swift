import SwiftUI

@main
struct TopMoviesApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.layoutDirection, .leftToRight)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1240, height: 830)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { store.showSettings = true }.keyboardShortcut(",")
            }
            CommandMenu("Catalog") {
                Button("Refresh") { store.refresh(force: true) }.keyboardShortcut("r")
                Button("Filters") { store.showFilters.toggle() }.keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Reset Filters") { store.filters = CatalogFilter() }.keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }
    }
}

enum Theme {
    static let background = Color(red: 0.065, green: 0.075, blue: 0.09)
    static let surface = Color(red: 0.10, green: 0.115, blue: 0.135)
    static let accent = Color(red: 0.97, green: 0.72, blue: 0.32)
}
