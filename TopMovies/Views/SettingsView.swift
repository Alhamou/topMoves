import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                if let logo = Bundle.main.url(forResource: "AppLogo", withExtension: "png").flatMap({ NSImage(contentsOf: $0) })
                    ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap({ NSImage(contentsOf: $0) })
                    ?? NSImage(named: "AppLogo") {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings & Sources").font(.title2.weight(.semibold))
                    Text("TopMovies for Mac · v0.1.0").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(store.tokenPresent ? "TMDB token stored in Keychain" : "Demo mode · no API token", systemImage: store.tokenPresent ? "key.fill" : "rectangle.dashed").font(.headline)
                            Text("Connect with your TMDB API Read Access Token (Bearer token, not the short API key). A free noncommercial developer account is required.").font(.callout).foregroundStyle(.secondary)
                            SecureField("Paste API Read Access Token", text: $token).textFieldStyle(.roundedBorder)
                            HStack {
                                Button("Save & Connect") {
                                    do { try store.configure(token: token); token = ""; saved = true; error = nil } catch { self.error = error.localizedDescription }
                                }.buttonStyle(.borderedProminent).disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                if store.tokenPresent { Button("Remove Token & Use Demo") { do { try store.configure(token: ""); saved = false } catch { self.error = error.localizedDescription } } }
                                Link("Get a token", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                            }
                            if saved { Text("Token saved. Connection status will appear in the catalog.").font(.caption).foregroundStyle(Theme.accent) }
                            if let error { Text(error).foregroundStyle(Theme.accent).font(.callout) }
                        }.padding(10)
                    }
                    GroupBox("Your taste") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Preferred genre", selection: $store.preference) {
                                ForEach(["All genres"] + Set(TMDBClient.genres.values.flatMap { $0.keys }).sorted(), id: \.self) { Text($0) }
                            }.onChange(of: store.preference) { _, _ in store.persistFilters() }
                            Text("For You uses favorite genres, your ratings of 7 or more, and audience rating confidence. It runs locally using ordinary rules, with no AI model or external preference tracking.").font(.caption).foregroundStyle(.secondary)
                        }.padding(10)
                    }
                    GroupBox("Refresh & local privacy") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Refresh every 15 minutes while active, and when returning if due.", systemImage: "arrow.clockwise")
                            Text("Provider updates are not real-time. No updates run while the app is closed. Catalog snapshots and posters expire after 7 days; details refresh after 6 hours. Saved metadata expires within 180 days, retaining your own flags and ratings.")
                            Text("Filters and your library are stored on this Mac. Search and discovery requests go to TMDB; loading posters contacts TMDB's image CDN. Playing a trailer contacts its host only after you choose to play.")
                            Button("Clear Provider Cache") { Task { await store.clearProviderCache() } }.disabled(store.isDemo)
                        }.font(.callout).padding(10)
                    }
                    GroupBox("Data, ratings & rights") {
                        VStack(alignment: .leading, spacing: 12) {
                            SourceFooter()
                            Text("TMDB is free for noncommercial use with attribution, not an open-data license. Commercial use needs a separate agreement. Posters and trailers remain subject to their owners' rights. This app uses no third-party software dependencies or paid API.")
                            Text("No critic-rating provider is connected. TMDB scores are audience ratings. English metadata does not identify a translation or subtitle provider. No complete worldwide ban registry or scene-level advisory source is connected.")
                            Text("TMDB terms restrict AI/ML use. Recommendations here are traditional filtering and arithmetic rules; no training or AI service is used.")
                            HStack {
                                Link("TMDB terms", destination: URL(string: "https://www.themoviedb.org/api-terms-of-use")!)
                                Link("Film rating guide", destination: URL(string: "https://www.filmratings.com/ratings-guide/")!)
                                Link("TV rating guide", destination: URL(string: "https://www.tvguidelines.org/ratings.html")!)
                            }
                        }.font(.callout).padding(10)
                    }
                }
            }
        }.padding(24).frame(width: 720, height: 730).background(Theme.background).tint(Theme.accent)
    }
}
