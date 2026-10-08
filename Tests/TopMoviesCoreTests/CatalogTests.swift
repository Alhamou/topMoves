import Foundation
import Testing
@testable import TopMoviesCore

@Test func consensusBeatsTinyVoteSample() {
    #expect(Ranking.quality(rating: 10, votes: 1) < Ranking.quality(rating: 8.5, votes: 5000))
}

@Test func filmAndSeriesIDsCannotCollide() {
    #expect(MediaItem(id: 42, kind: .movie, title: "Movie").key != MediaItem(id: 42, kind: .tv, title: "Series").key)
}

@Test func certificationPolicyIsConservative() {
    var filters = CatalogFilter()
    var item = MediaItem(id: 1, kind: .movie, title: "Unrated")
    #expect(!filters.allows(item))
    item.certification = "PG-13"
    #expect(filters.allows(item))
    item.certification = "R"
    #expect(!filters.allows(item))
    filters.includeRestricted = true
    #expect(filters.allows(item))
    item.certification = "NC-17"
    #expect(!filters.allows(item))
    item.kind = .tv
    item.certification = "TV-MA"
    #expect(!filters.allows(item))
    item.certification = "PG-13"
    #expect(!filters.allows(item))
    filters.includeUnknown = true
    #expect(filters.allows(item))
    item.adult = true
    #expect(!filters.allows(item))
}

@Test func dateLanguageRegionAndSearchIntersect() {
    var filters = CatalogFilter()
    filters.language = "hi"
    filters.region = "India"
    filters.fromDate = "2024-01-01"
    filters.toDate = "2024-12-31"
    filters.query = "river"
    var item = MediaItem(id: 1, kind: .movie, title: "River", releaseDate: "2024-05-01", originalLanguage: "hi", countries: ["IN"], certification: "PG")
    #expect(filters.allows(item))
    item.releaseDate = "2023-05-01"
    #expect(!filters.allows(item))
    item.releaseDate = ""
    #expect(!filters.allows(item))
}

@Test func recommendationsExcludeWatchedAndRejected() {
    let items = DemoCatalog.items
    var library = UserLibrary()
    library.set(.favorite, for: items[0], enabled: true)
    library.set(.watched, for: items[1], enabled: true)
    library.set(.notInterested, for: items[2], enabled: true)
    let candidates = Ranking.recommendations(items, library: library, preferredGenre: "Drama")
    #expect(!candidates.contains { $0.item.key == items[1].key || $0.item.key == items[2].key })
    #expect(candidates.allSatisfy { !$0.reason.isEmpty })
}

@Test func filtersAndLibraryRoundTrip() throws {
    var filters = CatalogFilter()
    filters.media = .tv
    filters.language = "ar"
    filters.sort = .quality
    filters.includeUnknown = true
    #expect(try JSONDecoder().decode(CatalogFilter.self, from: JSONEncoder().encode(filters)) == filters)
    var library = UserLibrary()
    library.set(.watchlist, for: DemoCatalog.items[0], enabled: true)
    library.ratings[DemoCatalog.items[0].key] = 9
    let restored = try JSONDecoder().decode(UserLibrary.self, from: JSONEncoder().encode(library))
    #expect(restored.contains(.watchlist, key: DemoCatalog.items[0].key))
    #expect(restored.ratings[DemoCatalog.items[0].key] == 9)
}

@Test func trailersDeduplicateAndValidate() {
    let videos = [
        Trailer(id: "1", name: "Fan", key: "abcdefghijk", site: "YouTube", type: "Trailer", official: false),
        Trailer(id: "2", name: "Official", key: "ZYXWVUTSRQP", site: "YouTube", type: "Trailer", official: true),
        Trailer(id: "3", name: "Duplicate", key: "ZYXWVUTSRQP", site: "YouTube", type: "Trailer", official: true),
        Trailer(id: "4", name: "Bad", key: "../bad", site: "YouTube", type: "Trailer", official: true),
        Trailer(id: "5", name: "Clip", key: "12345678901", site: "YouTube", type: "Clip", official: true)
    ]
    #expect(Trailer.playable(videos).map(\.id) == ["2", "1"])
}

@Test func refreshIsDueAfterFifteenMinutes() {
    let now = Date(timeIntervalSince1970: 10000)
    #expect(Freshness.isDue(lastUpdate: nil, now: now))
    #expect(!Freshness.isDue(lastUpdate: now.addingTimeInterval(-899), now: now))
    #expect(Freshness.isDue(lastUpdate: now.addingTimeInterval(-900), now: now))
}
