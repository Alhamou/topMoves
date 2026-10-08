import SwiftUI
import WebKit

struct DetailView: View {
    @Bindable var store: AppStore
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @State private var trailers: [Trailer] = []
    @State private var activeTrailer: Trailer?
    @State private var videoLoading = false
    @State private var videoError: String?
    @State private var episodes: [Episode] = []
    @State private var seasonNumber: Int?
    @State private var episodeLoading = false
    @State private var episodeError: String?
    private var runtimeText: String { item.runtime.map { "\($0) min\(item.kind == .tv ? " / episode" : "")" } ?? "Runtime unavailable" }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(item.kind.label, systemImage: item.kind == .movie ? "film" : "tv").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 26) {
                        PosterView(item: item).frame(width: 210).clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 16) {
                            if item.isDemo { Label("Fictional illustrative title", systemImage: "rectangle.dashed").font(.caption).foregroundStyle(Theme.accent) }
                            Text(item.title).font(.system(size: 30, weight: .semibold, design: .rounded)).textSelection(.enabled)
                            Text([item.year, runtimeText, item.status].filter { !$0.isEmpty }.joined(separator: "  ·  ")).font(.callout).foregroundStyle(.secondary)
                            Text("\(item.kind == .tv ? "First aired" : "Release date"): \(item.releaseDate.isEmpty ? "Not provided" : item.releaseDate)").font(.caption).foregroundStyle(.secondary)
                            Text(item.genres.joined(separator: " · ")).font(.callout).foregroundStyle(Theme.accent)
                            HStack(alignment: .top, spacing: 18) {
                                metric("US Content Rating", value: item.certification ?? "Unknown", source: item.isDemo ? "Illustrative label" : "TMDB · United States", symbol: "shield.lefthalf.filled")
                                metric("Audience", value: item.votes > 0 ? "\(item.rating.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(1)))) / 10" : "Unrated", source: item.isDemo ? "Fictional · \(item.votes.formatted(.number.locale(Locale(identifier: "en_US")))) votes" : "TMDB · \(item.votes.formatted(.number.locale(Locale(identifier: "en_US")))) votes", symbol: "star.fill")
                            }
                            metric("Critics", value: "Not available", source: "No licensed critic-score source connected", symbol: "quote.bubble")
                            Text(item.kind == .tv ? "Series-level US label; individual episodes or versions may differ. Classification is not a complete scene-by-scene advisory." : "US classification is not a guarantee of suitability or a complete content advisory.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    libraryActions
                    if store.feed == .recommendations {
                        Label(store.recommendationReason(item), systemImage: "sparkles").font(.callout).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    section("Story") {
                        Text(item.overview.isEmpty ? "An English synopsis is not available from the provider." : item.overview)
                            .font(.body).lineSpacing(5).textSelection(.enabled)
                    }
                    HStack(alignment: .top, spacing: 30) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Original title").font(.caption).foregroundStyle(.secondary)
                            Text(item.originalTitle.isEmpty ? "Not provided" : item.originalTitle).textSelection(.enabled)
                            Text("Original language").font(.caption).foregroundStyle(.secondary)
                            Text(Locale(identifier: "en_US").localizedString(forLanguageCode: item.originalLanguage) ?? item.originalLanguage)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Countries").font(.caption).foregroundStyle(.secondary)
                            Text(item.countries.isEmpty ? "Not provided" : item.countries.map { Locale(identifier: "en_US").localizedString(forRegionCode: $0) ?? $0 }.joined(separator: ", "))
                            Text("Provider origin countries; production countries used when origin is absent.").font(.caption2).foregroundStyle(.secondary)
                            if item.kind == .movie {
                                Text("Reported movie revenue").font(.caption).foregroundStyle(.secondary)
                                Text(item.revenue.map { $0.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")).precision(.fractionLength(0))) } ?? "Not reported")
                                Text("\(item.isDemo ? "Fictional amount" : "TMDB reported total") · not weekly box office, not adjusted for inflation").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !item.crew.isEmpty { peopleSection("Behind the story", people: item.crew) }
                    if !item.cast.isEmpty { peopleSection("Cast", people: item.cast) }
                    if item.kind == .tv { seasonSection }
                    trailerSection
                    section("Sources & context") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(item.isDemo ? "All metadata on this page is fictional demo content." : "Catalog, audience ratings, US labels & English metadata: TMDB", systemImage: "info.circle")
                            Label("Translation / subtitle provider: not identified by the catalog", systemImage: "captions.bubble")
                            Text("English metadata does not identify a translation company or confirm English subtitles. Exhibition-ban information is not supplied; availability is not proof of legal exhibition in every country.")
                                .font(.caption).foregroundStyle(.secondary)
                            if !item.isDemo {
                                Link("View on TMDB", destination: URL(string: "https://www.themoviedb.org/\(item.kind.rawValue)/\(item.id)")!)
                                SourceFooter()
                            }
                        }.font(.callout)
                    }
                }.padding(26)
            }
        }.background(Theme.background).tint(Theme.accent).frame(width: 800, height: 760)
        .task(id: item.key) {
            trailers = item.trailers
            if !item.isDemo {
                videoLoading = true
                do { trailers = try await store.detailVideos(item) } catch { videoError = error.localizedDescription }
                videoLoading = false
            }
            seasonNumber = item.seasons.first?.number
        }
        .task(id: seasonNumber) {
            guard let number = seasonNumber else { return }
            episodes = []; episodeError = nil; episodeLoading = true
            do {
                let loaded = try await store.seasonEpisodes(item, number: number)
                try Task.checkCancellation(); episodes = loaded
            } catch is CancellationError { } catch { episodeError = error.localizedDescription }
            episodeLoading = false
        }
    }
    private func metric(_ title: String, value: String, source: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(title == "Audience" ? Theme.accent : .primary)
            Text(source).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var libraryActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(LibraryFlag.allCases, id: \.self) { flag in
                    Button { store.toggle(flag, item: item) } label: {
                        Label(flag.rawValue, systemImage: store.library.contains(flag, key: item.key) ? "\(flag.symbol).fill" : flag.symbol)
                    }.buttonStyle(.bordered).tint(store.library.contains(flag, key: item.key) ? Theme.accent : .gray)
                        .accessibilityValue(store.library.contains(flag, key: item.key) ? "Saved" : "Not saved")
                }
            }
            Picker("Your rating", selection: Binding(get: { store.library.ratings[item.key] ?? 0 }, set: { store.rate($0, item: item) })) {
                Text("Not rated").tag(0)
                ForEach(1...10, id: \.self) { Text("\($0) / 10").tag($0) }
            }.frame(width: 220)
        }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.title3.weight(.semibold)); content() }
    }
    private func avatarColor(for name: String) -> Color {
        let palette: [Color] = [
            Theme.accent,
            Color(red: 0.35, green: 0.65, blue: 0.85),
            Color(red: 0.85, green: 0.45, blue: 0.45),
            Color(red: 0.45, green: 0.75, blue: 0.55),
            Color(red: 0.75, green: 0.55, blue: 0.85),
            Color(red: 0.90, green: 0.65, blue: 0.35)
        ]
        let hash = abs(name.hashValue)
        return palette[hash % palette.count]
    }
    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    private func peopleSection(_ title: String, people: [Person]) -> some View {
        section(title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], alignment: .leading, spacing: 14) {
                ForEach(people, id: \.self) { person in
                    let color = avatarColor(for: person.name)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.35), color.opacity(0.12)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1.2))
                            Text(initials(for: person.name))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 40, height: 40)
                        .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.callout.weight(.medium)).lineLimit(1)
                            Text(person.role).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.06), lineWidth: 1))
                }
            }
        }
    }
    private var seasonSection: some View {
        section("Seasons & episodes") {
            if item.seasons.isEmpty { Text("Season information not provided.").foregroundStyle(.secondary) }
            else {
                Picker("Season", selection: $seasonNumber) {
                    ForEach(item.seasons) { Text("\($0.name) · \($0.episodeCount) episodes").tag(Optional($0.number)) }
                }.frame(maxWidth: 330)
                if episodeLoading { ProgressView("Loading episodes…") }
                if let episodeError { Text(episodeError).font(.callout).foregroundStyle(Theme.accent) }
                ForEach(episodes) { episode in
                    DisclosureGroup {
                        Text(episode.overview.isEmpty ? "English episode synopsis unavailable." : episode.overview).font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    } label: {
                        HStack { Text("\(episode.number). \(episode.name)"); Spacer(); Text(episode.airDate).foregroundStyle(.secondary) }.font(.callout)
                    }.padding(10).background(Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                }
                Text("Episode-level US content certificates are not available in this integration.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var trailerSection: some View {
        section("Trailers & teasers") {
            if videoLoading { ProgressView("Finding trailers…") }
            if let videoError { Text(videoError).font(.callout).foregroundStyle(Theme.accent) }
            if trailers.isEmpty && !videoLoading {
                Label(item.isDemo ? "No real trailers exist for these fictional demo titles." : "No supported trailers were returned by TMDB.", systemImage: "play.rectangle").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(trailers) { trailer in
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle").font(.title2).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trailer.name).font(.callout.weight(.medium))
                        Text("\(trailer.site) · \(trailer.type)\(trailer.official ? " · marked official by TMDB" : "")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if trailer.site == "YouTube" { Button("Play here") { activeTrailer = trailer }.buttonStyle(.bordered) }
                    if let url = trailer.url { Link("Open \(trailer.site)", destination: url).font(.callout) }
                }.padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            }
            if let trailer = activeTrailer {
                HStack { Text("\(trailer.site) player").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Close player") { activeTrailer = nil }.buttonStyle(.link) }
                EmbeddedTrailer(key: trailer.key).frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Playback depends on the host, uploader and region. Use Open YouTube if embedding is unavailable.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct EmbeddedTrailer: NSViewRepresentable {
    let key: String
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: config)
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        guard key.count == 11, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return }
        let url = URL(string: "https://www.youtube-nocookie.com/embed/\(key)?autoplay=0&rel=0")!
        if view.url != url { view.load(URLRequest(url: url)) }
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: ()) { view.stopLoading(); view.loadHTMLString("", baseURL: nil) }
}
