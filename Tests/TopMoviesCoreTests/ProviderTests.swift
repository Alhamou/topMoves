import Foundation
import Testing
@testable import TopMoviesCore

private actor FixtureTransport: HTTPTransport {
    var count = 0
    let status: Int
    let body: Data
    let headers: [String: String]
    init(status: Int = 200, body: String = "{}", headers: [String: String] = [:]) {
        self.status = status; self.body = Data(body.utf8); self.headers = headers
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        count += 1
        #expect(request.url?.host == "api.themoviedb.org")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture")
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}
@Test func providerDistinguishesBadCredentials() async throws {
    let client = TMDBClient(token: "fixture", transport: FixtureTransport(status: 401))
    await #expect(throws: ProviderError.unauthorized) {
        try await client.catalog(filters: CatalogFilter(), feed: .discover, page: 1, force: true)
    }
}
@Test func providerBacksOffWithoutRepeatedRequests() async throws {
    let transport = FixtureTransport(status: 429, headers: ["Retry-After":"120"])
    let client = TMDBClient(token: "fixture", transport: transport)
    for _ in 0..<2 {
        await #expect(throws: ProviderError.rateLimited(120)) {
            try await client.catalog(filters: CatalogFilter(), feed: .discover, page: 1, force: true)
        }
    }
    #expect(await transport.count == 1)
}
@Test func usCertificateNeverFallsBackToAnotherCountryAndDetailsAreCached() async throws {
    let body = """
    {"title":"Fixture","genres":[{"id":18,"name":"Drama"}],"runtime":101,"production_countries":[{"iso_3166_1":"FR"}],"release_dates":{"results":[{"iso_3166_1":"FR","release_dates":[{"certification":"12","type":3}]}]},"videos":{"results":[]}}
    """
    let transport = FixtureTransport(body: body)
    let client = TMDBClient(token: "fixture", transport: transport)
    let source = MediaItem(id: 1, kind: .movie, title: "Fixture")
    let first = try await client.detail(source)
    #expect(first.certification == nil)
    #expect(first.runtime == 101)
    #expect(first.countries == ["FR"])
    #expect(first.genres == ["Drama"])
    let second = try await client.detail(source)
    #expect(second == first)
    #expect(await transport.count == 1)
}
@Test func tvContentCertificateAndSeasonDataAreDecodedSeparately() async throws {
    let body = """
    {"name":"Series fixture","genres":[{"id":9648,"name":"Mystery"}],"episode_run_time":[44],"status":"Ended","content_ratings":{"results":[{"iso_3166_1":"US","rating":"TV-14"}]},"seasons":[{"id":10,"season_number":1,"name":"Season 1","episode_count":8,"air_date":"2024-01-01","overview":"Story"}],"videos":{"results":[]}}
    """
    let client = TMDBClient(token: "fixture", transport: FixtureTransport(body: body))
    let item = try await client.detail(MediaItem(id: 1, kind: .tv, title: "Fixture"))
    #expect(item.certification == "TV-14")
    #expect(item.seasons.first?.episodeCount == 8)
    #expect(item.runtime == 44)
    #expect(item.revenue == nil)
}
@Test func requestedReleaseWindowMeansFirstAirDateForTV() async throws {
    let date = Date(timeIntervalSince1970: 1736942400) // January 2025
    var filter = CatalogFilter()
    filter.releaseWindow = "Last year"
    #expect(filter.releaseDates(now: date).0 == "2024-01-01")
    #expect(filter.releaseDates(now: date).1 == "2024-12-31")
}
@Test func personalFlagsSurviveProviderMetadataExpiry() {
    var library = UserLibrary()
    var item = DemoCatalog.items[0]; item.isDemo = false
    library.set(.favorite, for: item, enabled: true)
    library.updated[item.key] = .distantPast
    library.purgeExpiredMetadata()
    #expect(library.items[item.key] == nil)
    #expect(library.contains(.favorite, key: item.key))
}

@Test func savedIDLookupRestoresFullMetadataAfterExpiry() async throws {
    let body = """
    {"id":8,"title":"Restored","original_title":"Original","release_date":"2024-02-01","original_language":"fr","origin_country":["FR"],"production_countries":[{"iso_3166_1":"US"}],"vote_average":8.1,"vote_count":1234,"genres":[{"id":18,"name":"Drama"}],"runtime":99,"release_dates":{"results":[{"iso_3166_1":"US","release_dates":[{"certification":"PG","type":3}]}]}}
    """
    let client = TMDBClient(token: "fixture", transport: FixtureTransport(body: body))
    let item = try await client.lookup(id: 8, kind: .movie)
    #expect(item.rating == 8.1 && item.votes == 1234)
    #expect(item.countries == ["FR"])
    #expect(item.releaseDate == "2024-02-01")
    #expect(item.certification == "PG")
}

@Test func unknownRevenueIsNotTreatedAsZeroReceipts() {
    var filters = CatalogFilter(); filters.sort = .revenue
    var item = DemoCatalog.items[0]; item.revenue = nil
    #expect(!filters.allows(item))
}

@Test func voteCountSortUsesParticipationRatherThanRating() {
    var low = DemoCatalog.items[0]; low.votes = 1; low.rating = 10
    var many = DemoCatalog.items[1]; many.votes = 2000; many.rating = 7
    #expect(Ranking.sorted([low, many], by: .votes).first?.key == many.key)
}
