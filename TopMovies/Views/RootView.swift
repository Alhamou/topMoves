import SwiftUI

struct RootView: View {
    @Bindable var store: AppStore
    @Environment(\.scenePhase) private var phase
    @FocusState private var searchFocused: Bool
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    if let logo = Bundle.main.url(forResource: "AppLogo", withExtension: "png").flatMap({ NSImage(contentsOf: $0) })
                        ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap({ NSImage(contentsOf: $0) })
                        ?? NSImage(named: "AppLogo") {
                        Image(nsImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                    } else {
                        Image(systemName: "film.stack.fill").font(.title2).foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TopMovies").font(.system(size: 21, weight: .semibold, design: .rounded))
                        Text("STORIES WORTH YOUR TIME").font(.system(size: 8, weight: .medium)).tracking(1.3).foregroundStyle(.secondary)
                    }
                }.padding(20).padding(.top, 8)
                List(selection: $store.feed) {
                    Section("Explore") {
                        ForEach([Feed.discover, .recommendations, .tonight, .gems], id: \.self) { row($0) }
                    }
                    Section("In the spotlight") {
                        ForEach([Feed.daily, .weekly, .releases], id: \.self) { row($0) }
                    }
                    Section("Your library") {
                        ForEach([Feed.favorites, .watchlist, .watched, .rejected], id: \.self) { row($0) }
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 10) {
                    Label(store.isDemo ? "Demo catalog" : "TMDB connected", systemImage: store.isDemo ? "rectangle.dashed" : "checkmark.seal")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { store.showSettings = true } label: { Label("Settings & Sources", systemImage: "gearshape") }
                        .buttonStyle(.plain).font(.callout)
                }.padding(20)
            }
            .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 250)
        } detail: {
            VStack(spacing: 0) {
                topBar
                Divider().opacity(0.4)
                if store.showFilters { FilterPanel(store: store).padding(20).background(Theme.surface); Divider() }
                catalog
            }.background(Theme.background)
        }
        .tint(Theme.accent)
        .frame(minWidth: 860, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { searchFocused = true } label: { Image(systemName: "magnifyingglass") }
                    .help("Focus search (⌘F)").keyboardShortcut("f")
            }
        }
        .sheet(item: $store.selected) { item in DetailView(store: store, item: item) }
        .sheet(isPresented: $store.showSettings) { SettingsView(store: store) }
        .onChange(of: store.filters) { _, _ in store.scheduleReload() }
        .onChange(of: store.filters.media) { _, new in
            if !store.genres.contains(store.filters.genre) { store.filters.genre = "All genres" }
            if new == .tv && store.filters.sort == .revenue { store.filters.sort = .popular }
        }
        .onChange(of: store.feed) { _, _ in store.scheduleReload() }
        .onChange(of: phase) { _, new in
            store.isActive = new == .active
            if new == .active { store.refresh() }
        }
        .task {
            store.scheduleReload()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                if store.isActive { store.refresh() }
            }
        }
    }
    private func row(_ feed: Feed) -> some View {
        Label(feed.rawValue, systemImage: feed.symbol).tag(feed).padding(.vertical, 3)
    }
    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search movies & TV shows", text: $store.filters.query)
                    .textFieldStyle(.plain).focused($searchFocused).accessibilityLabel("Search movies and TV shows")
                if !store.filters.query.isEmpty {
                    Button { store.filters.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).help("Clear search")
                }
            }.padding(10).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 420)
            Spacer(minLength: 0)
            Button { store.showFilters.toggle() } label: {
                Label(store.filters.minimumAge != .any ? "Filters (\(store.filters.minimumAge.rawValue))" : "Filters", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered).tint(store.showFilters || store.filters != CatalogFilter() ? Theme.accent : .gray)
            Button { store.refresh(force: true) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).disabled(store.isLoading).help("Refresh catalog (⌘R)")
        }.padding(.horizontal, 24).padding(.vertical, 14)
    }
    private var catalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(store.feed.rawValue).font(.system(size: 32, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("\(store.visibleItems.count) loaded").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(store.subtitle).font(.callout).foregroundStyle(.secondary)
                }
                if store.isDemo {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.dashed").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Illustrative demo").font(.callout.weight(.semibold))
                            Text("Fictional titles, scores and US labels. Connect TMDB for real movies and series.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Connect") { store.showSettings = true }.buttonStyle(.bordered)
                    }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
                controls
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.genres, id: \.self) { genre in
                            Button { store.filters.genre = genre } label: {
                                Text(genre).font(.callout.weight(store.filters.genre == genre ? .semibold : .regular))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(store.filters.genre == genre ? Theme.accent : .white.opacity(0.055), in: Capsule())
                                    .foregroundStyle(store.filters.genre == genre ? Color.black : .white.opacity(0.8))
                            }.buttonStyle(.plain).accessibilityAddTraits(store.filters.genre == genre ? [.isSelected] : [])
                        }
                    }
                }
                statusLine
                if let error = store.error {
                    HStack(alignment: .top) {
                        Image(systemName: "wifi.exclamationmark").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.showingCached ? "Showing saved data" : "Couldn't update the catalog").font(.headline)
                            Text(error).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Retry") { store.refresh(force: true) }.disabled(store.isLoading)
                    }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
                if let error = store.librarySaveError { Text(error).foregroundStyle(Theme.accent).font(.callout) }
                if let notice = store.sparseNotice, !store.isLoading {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "line.3.horizontal.decrease.circle").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sparse Results").font(.callout.weight(.medium))
                            Text(notice).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.hasMore {
                            Button("Scan further") { store.loadMore() }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }.padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                }
                if store.isLoading && store.items.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 210), spacing: 20)], spacing: 24) {
                        ForEach(0..<8) { _ in
                            RoundedRectangle(cornerRadius: 8).fill(Theme.surface).aspectRatio(2 / 3, contentMode: .fit).overlay(ProgressView())
                        }
                    }.accessibilityLabel("Loading catalog and US content ratings")
                } else if store.visibleItems.isEmpty {
                    ContentUnavailableView {
                        Label(store.feed.isLibrary ? "No matching saved titles" : "No matching titles", systemImage: "film")
                    } description: {
                        Text(store.isLoading ? "Checking classifications…" : (store.sparseNotice ?? "Try broader filters. Unknown US ratings and mature content are hidden by default.\(store.hasMore ? " More candidates are available on the next page." : "")"))
                    } actions: {
                        HStack(spacing: 12) {
                            Button("Reset Filters") { store.filters = CatalogFilter() }
                            if store.hasMore && !store.isLoading {
                                Button("Scan Next Pages") { store.loadMore() }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .frame(minHeight: 230)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 220), spacing: 20)], alignment: .leading, spacing: 28) {
                        ForEach(store.visibleItems, id: \.key) { item in
                            PosterCard(store: store, item: item)
                                .onAppear {
                                    triggerScrollLoadMoreIfNeeded(for: item)
                                }
                        }
                    }
                }
                if store.hasMore {
                    HStack {
                        Spacer()
                        Button { store.loadMore() } label: {
                            HStack {
                                if store.isLoading { ProgressView().controlSize(.small) }
                                Text(store.isLoading ? "Loading…" : "Load more posters")
                            }
                        }.buttonStyle(.bordered).disabled(store.isLoading)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .onAppear {
                        if store.visibleItems.count >= 6 && !store.isLoading && store.hasMore {
                            store.loadMore()
                        }
                    }
                }
                if !store.isDemo { SourceFooter() }
                Text("Conservative US content filter · No claim of complete content advisories or worldwide exhibition-ban coverage.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
            }.padding(24)
        }
    }
    private func triggerScrollLoadMoreIfNeeded(for item: MediaItem) {
        guard !store.isLoading, store.hasMore else { return }
        let items = store.visibleItems
        guard items.count >= 6 else { return }
        if let idx = items.firstIndex(where: { $0.key == item.key }), idx >= items.count - 4 {
            store.loadMore()
        }
    }
    private var controls: some View {
        HStack(spacing: 16) {
            Picker("Media Type", selection: $store.filters.media) {
                ForEach(MediaSelection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 300)
            Spacer(minLength: 0)
            if store.feed == .releases {
                Picker("Period", selection: $store.filters.releaseWindow) {
                    ForEach(["Last 7 days","Last 30 days","This year","Last year"], id: \.self) { Text($0) }
                }.frame(width: 195)
            } else if ![.daily, .weekly, .recommendations].contains(store.feed) {
                Picker("Sort", selection: $store.filters.sort) {
                    ForEach(SortOrder.allCases.filter { store.filters.media != .tv || $0 != .revenue }, id: \.self) { Text($0.rawValue).tag($0) }
                }.frame(width: 230)
            }
        }
    }
    private var statusLine: some View {
        HStack(spacing: 8) {
            if store.isLoading { ProgressView().controlSize(.mini); Text("Checking details & US ratings…") }
            else {
                Image(systemName: store.showingCached ? "clock.badge.exclamationmark" : "checkmark.circle")
                if store.isDemo { Text("Offline preview · not live provider data") }
                else if let date = store.lastUpdated { Text("\(store.showingCached ? "Saved catalog" : (store.feed.isLibrary ? "Library checked" : "Catalog fetched")) \(date.formatted(.dateTime.locale(Locale(identifier: "en_US")).month(.abbreviated).day().year().hour().minute()))") }
                else { Text("Ready to connect") }
            }
            Spacer()
            if store.feed == .releases {
                let dates = store.effectiveFilters
                Text("\(dates.fromDate) → \(dates.toDate)")
            } else if store.filters != CatalogFilter() {
                Button("Reset") { store.filters = CatalogFilter() }.buttonStyle(.link)
            }
        }.font(.caption).foregroundStyle(.secondary)
    }
}
struct PosterCard: View {
    @Bindable var store: AppStore
    let item: MediaItem
    @State private var hovered = false
    private var isWatched: Bool { store.library.contains(.watched, key: item.key) }
    private var isFavorite: Bool { store.library.contains(.favorite, key: item.key) }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button { store.selected = item } label: {
                PosterView(item: item)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        Text(item.kind.label).font(.system(size: 9, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.black.opacity(0.75), in: Capsule()).padding(9)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isWatched {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                                Text("WATCHED").font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Color.green.opacity(0.9), in: Capsule())
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                            .padding(9)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Label(item.rating.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent).padding(7)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6)).padding(9)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(hovered ? Theme.accent.opacity(0.7) : (isWatched ? Color.green.opacity(0.35) : .white.opacity(0.07)), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityLabel("\(item.title), \(item.kind.label), audience rating \(item.rating), US \(item.certification ?? "unknown"), open details")
            HStack(alignment: .top, spacing: 6) {
                Text(item.title).font(.callout.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 7) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.toggle(.watched, item: item)
                        }
                    } label: {
                        Image(systemName: isWatched ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 15, weight: isWatched ? .semibold : .regular))
                            .foregroundStyle(isWatched ? Color.green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isWatched ? "Watched (click to remove)" : "Mark as watched")
                    .accessibilityLabel("Toggle watched for \(item.title)")
                    .accessibilityValue(isWatched ? "Watched" : "Not watched")

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.toggle(.favorite, item: item)
                        }
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 15))
                            .foregroundStyle(isFavorite ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle favorite")
                    .accessibilityLabel("Toggle favorite for \(item.title)")
                    .accessibilityValue(isFavorite ? "Saved" : "Not saved")
                }
            }
            HStack(spacing: 5) {
                Text(item.year.isEmpty ? "Date unknown" : item.year)
                Text("·")
                Text(item.ageRatingDisplay)
                    .font(.caption.weight(item.ageRatingDisplay == "18+" ? .semibold : .medium))
                    .foregroundStyle(item.ageRatingDisplay == "18+" ? Color(red: 0.95, green: 0.45, blue: 0.45) : (item.ageRatingDisplay == "16+" ? Color(red: 0.95, green: 0.65, blue: 0.35) : (item.ageRatingDisplay == "13+" ? Color(red: 0.92, green: 0.78, blue: 0.35) : .secondary)))
                Spacer(minLength: 0)
                if isWatched {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        Text("Watched").font(.caption2.weight(.medium))
                    }.foregroundStyle(Color.green)
                }
                if store.library.contains(.watchlist, key: item.key) { Image(systemName: "bookmark.fill").foregroundStyle(Theme.accent) }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovered = $0 }.contextMenu {
            Button("Show Details") { store.selected = item }
            ForEach(LibraryFlag.allCases, id: \.self) { flag in
                Button { store.toggle(flag, item: item) } label: { Label("\(store.library.contains(flag, key: item.key) ? "Remove from" : "Add to") \(flag.rawValue)", systemImage: flag.symbol) }
            }
        }
    }
}
struct SourceFooter: View {
    var body: some View {
        HStack(spacing: 12) {
            if let image = NSImage(named: "TMDB") { Image(nsImage: image).resizable().scaledToFit().frame(width: 82, height: 16).accessibilityLabel("TMDB") }
            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }.padding(.top, 12)
    }
}
