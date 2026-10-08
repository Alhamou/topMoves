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
    #expect(filters.allows(item))
    filters.includeRestricted = false
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

@Test func futureYearsAreExcludedByDefault() {
    let filters = CatalogFilter()
    let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
    let futureItem = MediaItem(id: 99, kind: .movie, title: "Future Sequel", releaseDate: "\(currentYear + 2)-05-01", certification: "PG")
    let currentItem = MediaItem(id: 100, kind: .movie, title: "Current Film", releaseDate: "\(currentYear)-05-01", certification: "PG")
    #expect(!filters.allows(futureItem))
    #expect(filters.allows(currentItem))

    var permissiveFilters = filters
    permissiveFilters.includeFutureYears = true
    #expect(permissiveFilters.allows(futureItem))

    var explicitDateFilters = filters
    explicitDateFilters.toDate = "\(currentYear + 2)-12-31"
    #expect(explicitDateFilters.allows(futureItem))
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

@Test func demoLibraryIdentityCannotOverlapLiveProviderIdentity() {
    var live = DemoCatalog.items[0]; live.isDemo = false
    #expect(live.key != DemoCatalog.items[0].key)
}

@Test func impossibleDatesAreRejectedBeforeNetworkRequests() {
    var filter = CatalogFilter()
    filter.fromDate = "2025-02-30"
    #expect(filter.dateValidationMessage != nil)
    filter.fromDate = "2025-03-01"; filter.toDate = "2025-02-01"
    #expect(filter.dateValidationMessage != nil)
    filter.fromDate = "2024-02-29"; filter.toDate = "2025-02-28"
    #expect(filter.dateValidationMessage == nil)
}

@Test func ageRatingParsingAndMinimumAgeFiltering() {
    #expect(AgeRating.age(for: "G", kind: .movie) == 0)
    #expect(AgeRating.age(for: "PG", kind: .movie) == 7)
    #expect(AgeRating.age(for: "PG-13", kind: .movie) == 13)
    #expect(AgeRating.age(for: "TV-14", kind: .tv) == 14)
    #expect(AgeRating.age(for: "16", kind: .movie) == 16)
    #expect(AgeRating.age(for: "FSK 16", kind: .movie) == 16)
    #expect(AgeRating.age(for: "R", kind: .movie) == 18)
    #expect(AgeRating.age(for: "NC-17", kind: .movie) == 18)
    #expect(AgeRating.age(for: "TV-MA", kind: .tv) == 18)

    var filters = CatalogFilter()
    let movieG = MediaItem(id: 1, kind: .movie, title: "Family Film", certification: "G")
    let moviePG13 = MediaItem(id: 2, kind: .movie, title: "Action Teen", certification: "PG-13")
    let movie16 = MediaItem(id: 3, kind: .movie, title: "European Thriller", certification: "16")
    let movieR = MediaItem(id: 4, kind: .movie, title: "Mature Horror", certification: "R")
    let tvMA = MediaItem(id: 5, kind: .tv, title: "Dark Series", certification: "TV-MA")

    // Age 13+
    filters.minimumAge = .age13
    #expect(!filters.allows(movieG))
    #expect(filters.allows(moviePG13))
    #expect(filters.allows(movie16))
    #expect(filters.allows(movieR))

    // Age 16+
    filters.minimumAge = .age16
    #expect(!filters.allows(movieG))
    #expect(!filters.allows(moviePG13))
    #expect(filters.allows(movie16))
    #expect(filters.allows(movieR))
    #expect(filters.allows(tvMA))

    // Age 18+
    filters.minimumAge = .age18
    #expect(!filters.allows(movieG))
    #expect(!filters.allows(moviePG13))
    #expect(!filters.allows(movie16))
    #expect(filters.allows(movieR))
    #expect(filters.allows(tvMA))
}

@Test func ageRatingDisplayFormatsClearNumbers() {
    #expect(MediaItem(id: 1, kind: .movie, title: "A", certification: "R").ageRatingDisplay == "18+")
    #expect(MediaItem(id: 2, kind: .movie, title: "B", certification: "NC-17").ageRatingDisplay == "18+")
    #expect(MediaItem(id: 3, kind: .tv, title: "C", certification: "TV-MA").ageRatingDisplay == "18+")
    #expect(MediaItem(id: 4, kind: .movie, title: "D", certification: "PG-13").ageRatingDisplay == "13+")
    #expect(MediaItem(id: 5, kind: .tv, title: "E", certification: "TV-14").ageRatingDisplay == "14+")
    #expect(MediaItem(id: 6, kind: .movie, title: "F", certification: "16").ageRatingDisplay == "16+")
    #expect(MediaItem(id: 7, kind: .movie, title: "G", certification: "PG").ageRatingDisplay == "7+")
    #expect(MediaItem(id: 8, kind: .movie, title: "H", certification: "G").ageRatingDisplay == "All")
    #expect(MediaItem(id: 9, kind: .movie, title: "I", certification: nil).ageRatingDisplay == "Unrated")
}


