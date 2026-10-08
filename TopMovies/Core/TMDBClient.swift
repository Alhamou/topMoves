import Foundation
import CryptoKit

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
public struct SessionTransport: HTTPTransport {
    private let session: URLSession
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024)
        session = URLSession(configuration: config)
    }
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        return (data, response)
    }
}
public enum ProviderError: Error, LocalizedError, Equatable {
    case missingToken, unauthorized, rateLimited(Int), invalidResponse, status(Int)
    public var errorDescription: String? {
        switch self {
        case .missingToken: "Add your TMDB API Read Access Token in Settings to connect."
        case .unauthorized: "TMDB rejected this token. Check your API Read Access Token in Settings."
        case .rateLimited(let seconds): "TMDB requested a pause. Try again in \(seconds) seconds."
        case .invalidResponse: "The data provider returned an unexpected response."
        case .status(let code): "The provider is unavailable (HTTP \(code)). Please try again later."
        }
    }
}
public struct CatalogPage: Sendable {
    public let items: [MediaItem]
    public let hasMore: Bool
    public let updated: Date
}
private struct CacheEntry: Codable {
    let stored: Date
    let data: Data
}
private struct PageDTO: Decodable {
    let results: [SummaryDTO]
    let totalPages: Int
    enum CodingKeys: String, CodingKey { case results, totalPages = "total_pages" }
}
private struct SummaryDTO: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let originalLanguage: String?
    let originCountry: [String]?
    let genreIDs: [Int]?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let posterPath: String?
    let adult: Bool?
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity, adult
        case originalTitle = "original_title", originalName = "original_name", releaseDate = "release_date", firstAirDate = "first_air_date"
        case originalLanguage = "original_language", originCountry = "origin_country", genreIDs = "genre_ids"
        case voteAverage = "vote_average", voteCount = "vote_count", posterPath = "poster_path"
    }
    func item(kind: MediaKind) -> MediaItem {
        MediaItem(id: id, kind: kind, title: title ?? name ?? "Untitled", originalTitle: originalTitle ?? originalName ?? "",
                  overview: overview ?? "", releaseDate: releaseDate ?? firstAirDate ?? "", originalLanguage: originalLanguage ?? "",
                  countries: originCountry ?? [], genreIDs: genreIDs ?? [], rating: voteAverage ?? 0, votes: voteCount ?? 0,
                  popularity: popularity ?? 0, adult: adult ?? false, posterPath: posterPath)
    }
}
private struct DetailDTO: Decodable {
    struct Genre: Decodable { let id: Int; let name: String }
    struct Country: Decodable { let iso31661: String; enum CodingKeys: String, CodingKey { case iso31661 = "iso_3166_1" } }
    struct Releases: Decodable {
        struct Country: Decodable {
            struct Release: Decodable { let certification: String; let type: Int }
            let country: String; let releaseDates: [Release]
            enum CodingKeys: String, CodingKey { case country = "iso_3166_1", releaseDates = "release_dates" }
        }
        let results: [Country]
    }
    struct ContentRatings: Decodable {
        struct Rating: Decodable { let country: String; let rating: String; enum CodingKeys: String, CodingKey { case country = "iso_3166_1", rating } }
        let results: [Rating]
    }
    struct Videos: Decodable { let results: [Trailer] }
    struct Credits: Decodable {
        struct Member: Decodable { let id: Int; let name: String; let character: String?; let job: String? }
        let cast: [Member]; let crew: [Member]
    }
    struct SeasonDTO: Decodable {
        let id: Int; let seasonNumber: Int; let name: String; let episodeCount: Int; let airDate: String?; let overview: String?
        enum CodingKeys: String, CodingKey { case id, name, overview, seasonNumber = "season_number", episodeCount = "episode_count", airDate = "air_date" }
    }
    let title: String?; let name: String?; let overview: String?; let genres: [Genre]?
    let runtime: Int?; let episodeRunTime: [Int]?; let productionCountries: [Country]?; let originCountry: [String]?
    let revenue: Int?; let status: String?; let adult: Bool?; let releases: Releases?; let contentRatings: ContentRatings?
    let videos: Videos?; let credits: Credits?; let seasons: [SeasonDTO]?
    enum CodingKeys: String, CodingKey {
        case title, name, overview, genres, runtime, revenue, status, adult, videos, credits, seasons
        case episodeRunTime = "episode_run_time", productionCountries = "production_countries", originCountry = "origin_country", releases = "release_dates", contentRatings = "content_ratings"
    }
    func enrich(_ value: MediaItem) -> MediaItem {
        var item = value
        item.title = title ?? name ?? item.title; item.overview = overview ?? item.overview
        item.genres = genres?.map(\.name) ?? []; item.genreIDs = genres?.map(\.id) ?? item.genreIDs
        item.runtime = runtime.flatMap { $0 > 0 ? $0 : nil } ?? episodeRunTime?.first(where: { $0 > 0 })
        if let originCountry, !originCountry.isEmpty { item.countries = originCountry }
        else if item.countries.isEmpty { item.countries = productionCountries?.map(\.iso31661) ?? [] }
        item.revenue = item.kind == .movie ? revenue.flatMap { $0 > 0 ? $0 : nil } : nil
        item.status = status ?? ""; item.adult = adult ?? item.adult
        if item.kind == .movie {
            let us = releases?.results.first { $0.country == "US" }
            // Prefer theatrical US certificates. Never fall back to another jurisdiction.
            item.certification = us?.releaseDates.filter { !$0.certification.isEmpty }.sorted {
                let order = [3, 2, 4, 5, 6, 1]
                return (order.firstIndex(of: $0.type) ?? 9) < (order.firstIndex(of: $1.type) ?? 9)
            }.first?.certification
        } else { item.certification = contentRatings?.results.first { $0.country == "US" }?.rating }
        item.trailers = Trailer.playable(videos?.results ?? [])
        item.cast = credits?.cast.prefix(12).map { Person(id: $0.id, name: $0.name, role: $0.character ?? "Cast") } ?? []
        item.crew = credits?.crew.filter { ["Director", "Writer", "Screenplay", "Executive Producer"].contains($0.job ?? "") }.prefix(8).map { Person(id: $0.id, name: $0.name, role: $0.job ?? "Crew") } ?? []
        item.seasons = seasons?.filter { $0.seasonNumber > 0 }.map {
            Season(id: $0.id, number: $0.seasonNumber, name: $0.name, episodeCount: $0.episodeCount, airDate: $0.airDate ?? "", overview: $0.overview ?? "")
        } ?? []
        return item
    }
}
public actor TMDBClient {
    private var token: String
    private let transport: any HTTPTransport
    private let cacheDirectory: URL?
    private var memory: [String: CacheEntry] = [:]
    private struct PendingRequest { let id: UUID; let task: Task<Data, Error> }
    private var pending: [String: PendingRequest] = [:]
    private var blockedUntil: Date?
    private func cacheTimestamp(_ path: String, query: [URLQueryItem]) -> Date {
        var url = URLComponents(string: "https://api.themoviedb.org/3/\(path)")!
        url.queryItems = query
        let key = SHA256.hash(data: Data(url.url!.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return memory[key]?.stored ?? Date()
    }
    public init(token: String, transport: any HTTPTransport = SessionTransport(), cacheDirectory: URL? = nil) {
        self.token = token; self.transport = transport; self.cacheDirectory = cacheDirectory
        if let cacheDirectory { try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true) }
    }
    private func request(_ path: String, query: [URLQueryItem] = [], ttl: TimeInterval = 0) async throws -> Data {
        try Task.checkCancellation()
        guard !token.isEmpty else { throw ProviderError.missingToken }
        if let until = blockedUntil, until > Date() { throw ProviderError.rateLimited(Int(ceil(until.timeIntervalSinceNow))) }
        var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)")!
        components.queryItems = query
        let url = components.url!
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        if memory[key] == nil, let file = cacheDirectory?.appendingPathComponent(key), let data = try? Data(contentsOf: file) {
            memory[key] = try? JSONDecoder().decode(CacheEntry.self, from: data)
        }
        if let cached = memory[key], Date().timeIntervalSince(cached.stored) < ttl { return cached.data }
        if let existing = pending[key], !existing.task.isCancelled {
            let data = try await existing.task.value
            try Task.checkCancellation()
            return data
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let transport = transport
        let task = Task<Data, Error> {
            let (data, response) = try await transport.data(for: request)
            if response.statusCode == 401 || response.statusCode == 403 { throw ProviderError.unauthorized }
            if response.statusCode == 429 { throw ProviderError.rateLimited(max(1, Int(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60)) }
            guard (200..<300).contains(response.statusCode) else { throw ProviderError.status(response.statusCode) }
            return data
        }
        let requestID = UUID()
        pending[key] = PendingRequest(id: requestID, task: task)
        do {
            let data = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            let entry = CacheEntry(stored: Date(), data: data); memory[key] = entry
            if let file = cacheDirectory?.appendingPathComponent(key), let encoded = try? JSONEncoder().encode(entry) { try? encoded.write(to: file, options: .atomic) }
            if pending[key]?.id == requestID { pending.removeValue(forKey: key) }
            return data
        } catch {
            if pending[key]?.id == requestID { pending.removeValue(forKey: key) }
            if case ProviderError.rateLimited(let seconds) = error { blockedUntil = Date().addingTimeInterval(Double(seconds)) }
            throw error
        }
    }
    public func clearCache() {
        memory.removeAll()
        for request in pending.values { request.task.cancel() }; pending.removeAll()
        if let dir = cacheDirectory, let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
    }
    public func pruneCache() {
        guard let dir = cacheDirectory, let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in files {
            let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if Date().timeIntervalSince(modified ?? .distantPast) > 604800 { try? FileManager.default.removeItem(at: file) }
        }
    }
    public func catalog(filters: CatalogFilter, feed: Feed, page: Int, force: Bool) async throws -> CatalogPage {
        var items: [MediaItem] = []; var hasMore = false; var updated = Date()
        for kind in filters.media.kinds where !(filters.sort == .revenue && kind == .tv) {
            var query = [URLQueryItem(name: "language", value: "en-US"), URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "include_adult", value: "false")]
            let path: String
            if !filters.query.isEmpty {
                path = "search/\(kind.rawValue)"; query.append(URLQueryItem(name: "query", value: filters.query))
            } else if feed == .daily || feed == .weekly { path = "trending/\(kind.rawValue)/\(feed == .daily ? "day" : "week")" }
            else {
                path = "discover/\(kind.rawValue)"
                let sort = kind == .tv && filters.sort == .newest ? "first_air_date.desc" : filters.sort.apiValue
                query.append(URLQueryItem(name: "sort_by", value: feed == .releases ? "vote_average.desc" : sort))
                query.append(URLQueryItem(name: "vote_count.gte", value: String(feed == .releases ? max(50, filters.minimumVotes) : filters.minimumVotes)))
                query.append(URLQueryItem(name: "vote_average.gte", value: String(filters.minimumRating)))
                if !filters.language.isEmpty { query.append(URLQueryItem(name: "with_original_language", value: filters.language)) }
                if !filters.country.isEmpty { query.append(URLQueryItem(name: "with_origin_country", value: filters.country)) }
                else if let regions = CatalogFilter.regions[filters.region], !regions.isEmpty { query.append(URLQueryItem(name: "with_origin_country", value: regions.joined(separator: "|"))) }
                if let id = Self.genres[kind]?[filters.genre] { query.append(URLQueryItem(name: "with_genres", value: String(id))) }
                var dates = (filters.fromDate, filters.toDate)
                if feed == .releases { dates = filters.releaseDates() }
                let prefix = kind == .movie ? "primary_release_date" : "first_air_date"
                if !dates.0.isEmpty { query.append(URLQueryItem(name: "\(prefix).gte", value: dates.0)) }
                if !dates.1.isEmpty {
                    query.append(URLQueryItem(name: "\(prefix).lte", value: dates.1))
                } else if !filters.includeFutureYears {
                    let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
                    query.append(URLQueryItem(name: "\(prefix).lte", value: "\(currentYear)-12-31"))
                }
                if filters.maximumRuntime > 0 { query.append(URLQueryItem(name: "with_runtime.lte", value: String(filters.maximumRuntime))) }
                if !filters.includeUnknown {
                    query.append(URLQueryItem(name: "certification_country", value: "US"))
                    if kind == .movie {
                        let certs: String
                        switch filters.minimumAge {
                        case .any:
                            certs = filters.includeRestricted ? "G|PG|PG-13|R" : "G|PG|PG-13"
                        case .age13:
                            certs = filters.includeRestricted ? "PG-13|R" : "PG-13"
                        case .age16, .age18:
                            certs = "R|NC-17"
                        }
                        query.append(URLQueryItem(name: "certification", value: certs))
                    } else {
                        let certs: String
                        switch filters.minimumAge {
                        case .any:
                            certs = "TV-Y|TV-Y7|TV-G|TV-PG|TV-14"
                        case .age13:
                            certs = "TV-14"
                        case .age16, .age18:
                            certs = "TV-MA"
                        }
                        query.append(URLQueryItem(name: "certification", value: certs))
                    }
                }
            }
            let data = try await request(path, query: query, ttl: force ? 0 : Freshness.interval)
            updated = min(updated, cacheTimestamp(path, query: query))
            let result = try JSONDecoder().decode(PageDTO.self, from: data)
            hasMore = hasMore || page < min(500, result.totalPages)
            items += result.results.map { $0.item(kind: kind) }.filter { !$0.adult }
        }
        var enriched: [MediaItem] = []
        // Bound concurrency. Certificate/detail requests are cached for six hours.
        for start in stride(from: 0, to: items.count, by: 4) {
            try Task.checkCancellation()
            let batch = Array(items[start..<min(start + 4, items.count)])
            let values = try await withThrowingTaskGroup(of: MediaItem?.self) { group in
                for item in batch { group.addTask {
                    do { return try await self.detail(item) }
                    catch ProviderError.status(404) { return nil }
                } }
                var values: [MediaItem] = []
                for try await value in group { if let value { values.append(value) } }
                return values
            }
            enriched += values
        }
        let order = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.key, $0.offset) })
        enriched.sort { order[$0.key, default: 0] < order[$1.key, default: 0] }
        return CatalogPage(items: enriched, hasMore: hasMore, updated: updated)
    }
    public func detail(_ item: MediaItem, force: Bool = false) async throws -> MediaItem {
        let appended = item.kind == .movie ? "release_dates,videos,credits" : "content_ratings,videos,credits"
        let data = try await request("\(item.kind.rawValue)/\(item.id)", query: [.init(name: "language", value: "en-US"), .init(name: "append_to_response", value: appended)], ttl: force ? 0 : 21600)
        return try JSONDecoder().decode(DetailDTO.self, from: data).enrich(item)
    }
    public func lookup(id: Int, kind: MediaKind, force: Bool = false) async throws -> MediaItem {
        let appended = kind == .movie ? "release_dates,videos,credits" : "content_ratings,videos,credits"
        let data = try await request("\(kind.rawValue)/\(id)", query: [.init(name: "language", value: "en-US"), .init(name: "append_to_response", value: appended)], ttl: force ? 0 : 21600)
        let summary = try JSONDecoder().decode(SummaryDTO.self, from: data).item(kind: kind)
        return try JSONDecoder().decode(DetailDTO.self, from: data).enrich(summary)
    }
    public func trailers(_ item: MediaItem) async throws -> [Trailer] {
        // Preserve English metadata; fetch original-language videos only when the English list is empty.
        if item.originalLanguage.isEmpty || item.originalLanguage == "en" { return item.trailers }
        let data = try await request("\(item.kind.rawValue)/\(item.id)/videos", query: [.init(name: "language", value: item.originalLanguage)], ttl: 21600)
        return Trailer.playable(item.trailers + (try JSONDecoder().decode(DetailDTO.Videos.self, from: data).results))
    }
    public func episodes(seriesID: Int, season: Int) async throws -> [Episode] {
        struct Response: Decodable {
            struct Value: Decodable {
                let id: Int; let episodeNumber: Int; let name: String; let overview: String?; let airDate: String?; let runtime: Int?
                enum CodingKeys: String, CodingKey { case id, name, overview, runtime, episodeNumber = "episode_number", airDate = "air_date" }
            }
            let episodes: [Value]
        }
        let data = try await request("tv/\(seriesID)/season/\(season)", query: [.init(name: "language", value: "en-US")], ttl: 21600)
        return try JSONDecoder().decode(Response.self, from: data).episodes.map { Episode(id: $0.id, number: $0.episodeNumber, name: $0.name, overview: $0.overview ?? "", airDate: $0.airDate ?? "", runtime: $0.runtime) }
    }
    public static let genres: [MediaKind: [String: Int]] = [
        .movie: ["Action":28,"Adventure":12,"Animation":16,"Comedy":35,"Crime":80,"Documentary":99,"Drama":18,"Family":10751,"Fantasy":14,"History":36,"Horror":27,"Music":10402,"Mystery":9648,"Romance":10749,"Science Fiction":878,"TV Movie":10770,"Thriller":53,"War":10752,"Western":37],
        .tv: ["Action & Adventure":10759,"Animation":16,"Comedy":35,"Crime":80,"Documentary":99,"Drama":18,"Family":10751,"Kids":10762,"Mystery":9648,"News":10763,"Reality":10764,"Sci-Fi & Fantasy":10765,"Soap":10766,"Talk":10767,"War & Politics":10768,"Western":37]
    ]
}
