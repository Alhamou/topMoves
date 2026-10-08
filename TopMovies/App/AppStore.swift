import SwiftUI
import Observation
import Security
import CryptoKit

@MainActor @Observable
final class AppStore {
    var filters: CatalogFilter
    var feed: Feed = .discover
    var items: [MediaItem] = []
    var library: UserLibrary
    var selected: MediaItem?
    var isLoading = false
    var hasMore = false
    var page = 1
    var error: String?
    var lastUpdated: Date?
    var showingCached = false
    var showSettings = false
    var showFilters = false
    var isActive = true
    var tokenPresent = false
    var preference = "All genres"
    var librarySaveError: String?
    private var client: TMDBClient?
    private var requestTask: Task<Void, Never>?
    private var generation = UUID()
    private let directory: URL
    private let defaults: UserDefaults
    private var lastAttempt: Date?

    var isDemo: Bool { !tokenPresent }
    var effectiveFilters: CatalogFilter {
        var value = filters
        if feed == .releases {
            let dates = filters.releaseDates(); value.fromDate = dates.0; value.toDate = dates.1
            value.minimumVotes = max(50, value.minimumVotes)
        }
        if feed == .tonight && value.maximumRuntime == 0 { value.maximumRuntime = 120 }
        return value
    }
    var visibleItems: [MediaItem] {
        var values = items.filter { effectiveFilters.allows($0) }
        if let flag = feed.flag { values = values.filter { library.contains(flag, key: $0.key) } }
        else { values = values.filter { !library.contains(.notInterested, key: $0.key) } }
        if [.recommendations, .tonight, .gems].contains(feed) {
            values = values.filter { !library.contains(.watched, key: $0.key) }
            if feed == .gems { values = values.filter { $0.votes >= 100 && $0.votes <= 3000 && $0.rating >= 7 } }
            if feed == .recommendations { return Ranking.recommendations(values, library: library, preferredGenre: preference).map(\.item) }
            return Ranking.sorted(values, by: .quality)
        }
        if [.daily, .weekly].contains(feed) { return values }
        return Ranking.sorted(values, by: feed == .releases ? .rating : filters.sort)
    }
    var genres: [String] {
        let values = filters.media.kinds.flatMap { Array(TMDBClient.genres[$0]?.keys ?? [:].keys) }
        return ["All genres"] + Set(values).sorted()
    }
    var subtitle: String {
        switch feed {
        case .discover: "A world of stories. Find your next favorite."
        case .recommendations: "Your taste, thoughtful choices. Traditional rules, explained."
        case .tonight: "Something good for the time you have. Known runtimes only."
        case .gems: "Highly rated, 100–3,000 votes. Ranked within loaded candidates."
        case .daily, .weekly: "TMDB interest trends, not audience rating charts."
        case .releases: "Best-rated new movies and series premieres · at least 50 votes."
        default: "Your private library, saved on this Mac. Content filters still apply."
        }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        filters = defaults.data(forKey: "catalogFilters").flatMap { try? JSONDecoder().decode(CatalogFilter.self, from: $0) } ?? CatalogFilter()
        preference = defaults.string(forKey: "preferredGenre") ?? "All genres"
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TopMovies", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        library = (try? Data(contentsOf: directory.appendingPathComponent("library.json"))).flatMap { try? JSONDecoder().decode(UserLibrary.self, from: $0) } ?? UserLibrary()
        library.purgeExpiredMetadata()
        library.normalizeKeys()
        let token = TokenVault.read() ?? ""
        tokenPresent = !token.isEmpty
        if tokenPresent { client = TMDBClient(token: token, cacheDirectory: directory.appendingPathComponent("provider-cache")) }
    }
    func persistFilters() {
        if let data = try? JSONEncoder().encode(filters) { defaults.set(data, forKey: "catalogFilters") }
        defaults.set(preference, forKey: "preferredGenre")
    }
    func scheduleReload() {
        persistFilters()
        requestTask?.cancel()
        let id = UUID(); generation = id
        requestTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await load(id: id, more: false, force: false)
        }
    }
    func refresh(force: Bool = false) {
        if isLoading && !force { return }
        if !force, !Freshness.isDue(lastUpdate: lastUpdated), !showingCached { return }
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
        requestTask?.cancel()
        let id = UUID(); generation = id
        requestTask = Task { await load(id: id, more: false, force: force) }
    }
    func loadMore() {
        guard !isLoading, hasMore else { return }
        let id = generation
        requestTask = Task { await load(id: id, more: true, force: false) }
    }
    private struct Snapshot: Codable { let items: [MediaItem]; let updated: Date; let hasMore: Bool; let page: Int }
    private var snapshotURL: URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(filters)) ?? Data()
        let hash = SHA256.hash(data: data + Data(feed.rawValue.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("snapshot-\(hash).json")
    }
    private func load(id: UUID, more: Bool, force: Bool) async {
        guard id == generation else { return }
        isLoading = true; error = nil; lastAttempt = Date()
        if feed != .releases, let message = filters.dateValidationMessage {
            error = message; isLoading = false; return
        }
        let snapshotFile = snapshotURL
        if !more {
            page = 1; hasMore = false; lastUpdated = nil; showingCached = false
            items = feed.isLibrary ? Array(library.items.values) : []
            if isDemo { items = DemoCatalog.items; hasMore = false; isLoading = false; return }
            if !feed.isLibrary, let data = try? Data(contentsOf: snapshotFile), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), Date().timeIntervalSince(snapshot.updated) < 604800 {
                items = snapshot.items; lastUpdated = snapshot.updated; showingCached = true
                hasMore = snapshot.hasMore; page = snapshot.page
            }
        }
        guard let client else { isLoading = false; return }
        let requestPage = more ? page + 1 : 1
        do {
            let values: [MediaItem]; let moreAvailable: Bool; let fetchedAt: Date
            if let flag = feed.flag {
                let savedKeys = library.flags.keys.filter { library.contains(flag, key: $0) && !$0.hasPrefix("demo:") }.sorted()
                var refreshed: [MediaItem] = []
                for key in savedKeys {
                    try Task.checkCancellation()
                    let parts = key.split(separator: ":")
                    guard parts.count == 2, let kind = MediaKind(rawValue: String(parts[0])), let mediaID = Int(parts[1]) else { continue }
                    do { refreshed.append(try await client.lookup(id: mediaID, kind: kind, force: force)) }
                    catch ProviderError.status(404) { continue }
                }
                values = refreshed; moreAvailable = false; fetchedAt = Date()
            } else {
                let result = try await client.catalog(filters: effectiveFilters, feed: feed, page: requestPage, force: force)
                values = result.items; moreAvailable = result.hasMore; fetchedAt = result.updated
            }
            try Task.checkCancellation()
            guard id == generation else { return }
            var merged = more ? items : []
            var seen = Set(merged.map(\.key))
            for item in values where seen.insert(item.key).inserted { merged.append(item) }
            items = merged; hasMore = moreAvailable; page = requestPage
            lastUpdated = fetchedAt; showingCached = false
            for item in values where library.items[item.key] != nil || library.flags[item.key] != nil {
                library.items[item.key] = item; library.updated[item.key] = Date()
            }
            saveLibrary()
            let snapshot = Snapshot(items: items, updated: lastUpdated!, hasMore: hasMore, page: page)
            if !feed.isLibrary, let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: snapshotFile, options: .atomic) }
            await client.pruneCache()
            pruneSnapshots()
        } catch is CancellationError { }
        catch {
            guard id == generation else { return }
            if !Task.isCancelled { self.error = error.localizedDescription; showingCached = !items.isEmpty }
        }
        if id == generation { isLoading = false }
    }
    func toggle(_ flag: LibraryFlag, item: MediaItem) {
        library.set(flag, for: item, enabled: !library.contains(flag, key: item.key)); saveLibrary()
    }
    func rate(_ rating: Int, item: MediaItem) {
        library.items[item.key] = item; library.updated[item.key] = Date()
        if rating == 0 { library.ratings.removeValue(forKey: item.key) } else { library.ratings[item.key] = rating }
        saveLibrary()
    }
    private func saveLibrary() {
        do { let data = try JSONEncoder().encode(library); try data.write(to: directory.appendingPathComponent("library.json"), options: .atomic); librarySaveError = nil }
        catch { librarySaveError = "Your latest library changes could not be saved to this Mac." }
    }
    func configure(token: String) throws {
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        try TokenVault.save(cleaned)
        requestTask?.cancel()
        let old = client
        tokenPresent = !cleaned.isEmpty
        client = cleaned.isEmpty ? nil : TMDBClient(token: cleaned, cacheDirectory: directory.appendingPathComponent("provider-cache"))
        items = []; lastUpdated = nil
        Task { await old?.clearCache() }
        scheduleReload()
    }
    func clearProviderCache() async {
        await client?.clearCache()
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("snapshot-") { try? FileManager.default.removeItem(at: file) }
        }
        refresh(force: true)
    }
    private func pruneSnapshots() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in files where file.lastPathComponent.hasPrefix("snapshot-") {
            let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if Date().timeIntervalSince(date ?? .distantPast) > 604800 { try? FileManager.default.removeItem(at: file) }
        }
    }
    func recommendationReason(_ item: MediaItem) -> String {
        Ranking.recommendations([item], library: library, preferredGenre: preference).first?.reason ?? ""
    }
    func detailVideos(_ item: MediaItem) async throws -> [Trailer] {
        guard !item.isDemo, let client else { return [] }; return try await client.trailers(item)
    }
    func seasonEpisodes(_ item: MediaItem, number: Int) async throws -> [Episode] {
        if item.isDemo {
            return (1...8).map { Episode(id: item.id * 1000 + $0, number: $0, name: "Chapter \($0) (illustrative)", overview: "Fictional episode used to preview the season layout.", airDate: item.releaseDate, runtime: item.runtime) }
        }
        guard let client else { return [] }; return try await client.episodes(seriesID: item.id, season: number)
    }
}

@MainActor enum TokenVault {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.topmovies.tmdb", kSecAttrAccount as String: "read-access-token"]
    static func read() -> String? {
        var request = query; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        guard !token.isEmpty else { SecItemDelete(query as CFDictionary); return }
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query; request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw VaultError.failed }
        } else if status != errSecSuccess { throw VaultError.failed }
    }
    enum VaultError: LocalizedError { case failed; var errorDescription: String? { "The token could not be saved in Keychain. Try again." } }
}
