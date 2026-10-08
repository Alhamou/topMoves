import Foundation

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case movie, tv
    public var label: String { self == .movie ? "Movie" : "TV Show" }
}
public enum MediaSelection: String, Codable, CaseIterable, Sendable {
    case all = "All", movie = "Movies", tv = "TV Shows"
    public var kinds: [MediaKind] { self == .all ? [.movie, .tv] : [self == .movie ? .movie : .tv] }
}
public struct Person: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let role: String
}
public struct Season: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let name: String
    public let episodeCount: Int
    public let airDate: String
    public let overview: String
}
public struct Episode: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let name: String
    public let overview: String
    public let airDate: String
    public let runtime: Int?
}
public struct Trailer: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let key: String
    public let site: String
    public let type: String
    public let official: Bool
    public var url: URL? {
        let valid = !key.isEmpty && key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
        guard valid else { return nil }
        if site == "YouTube", key.count == 11 { return URL(string: "https://www.youtube.com/watch?v=\(key)") }
        if site == "Vimeo", key.allSatisfy(\.isNumber) { return URL(string: "https://vimeo.com/\(key)") }
        return nil
    }
    public static func playable(_ values: [Trailer]) -> [Trailer] {
        var seen = Set<String>()
        return values.sorted { $0.official && !$1.official }.filter {
            ["Trailer", "Teaser"].contains($0.type) && $0.url != nil && seen.insert("\($0.site):\($0.key)").inserted
        }
    }
}
public struct MediaItem: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var kind: MediaKind
    public var title: String
    public var originalTitle: String
    public var overview: String
    public var releaseDate: String
    public var originalLanguage: String
    public var countries: [String]
    public var genres: [String]
    public var genreIDs: [Int]
    public var rating: Double
    public var votes: Int
    public var popularity: Double
    public var runtime: Int?
    public var certification: String?
    public var adult: Bool
    public var posterPath: String?
    public var revenue: Int?
    public var status: String
    public var cast: [Person]
    public var crew: [Person]
    public var trailers: [Trailer]
    public var seasons: [Season]
    public var isDemo: Bool
    public var key: String { "\(isDemo ? "demo:" : "")\(kind.rawValue):\(id)" }
    public var year: String { String(releaseDate.prefix(4)) }
    public init(id: Int, kind: MediaKind, title: String, originalTitle: String = "", overview: String = "", releaseDate: String = "", originalLanguage: String = "en", countries: [String] = [], genres: [String] = [], genreIDs: [Int] = [], rating: Double = 0, votes: Int = 0, popularity: Double = 0, runtime: Int? = nil, certification: String? = nil, adult: Bool = false, posterPath: String? = nil, revenue: Int? = nil, status: String = "", cast: [Person] = [], crew: [Person] = [], trailers: [Trailer] = [], seasons: [Season] = [], isDemo: Bool = false) {
        self.id = id; self.kind = kind; self.title = title; self.originalTitle = originalTitle
        self.overview = overview; self.releaseDate = releaseDate; self.originalLanguage = originalLanguage
        self.countries = countries; self.genres = genres; self.genreIDs = genreIDs; self.rating = rating
        self.votes = votes; self.popularity = popularity; self.runtime = runtime; self.certification = certification
        self.adult = adult; self.posterPath = posterPath; self.revenue = revenue; self.status = status
        self.cast = cast; self.crew = crew; self.trailers = trailers; self.seasons = seasons; self.isDemo = isDemo
    }
}
public enum SortOrder: String, Codable, CaseIterable, Sendable {
    case popular = "Popular", rating = "Audience rating", quality = "Rating confidence", votes = "Vote count", newest = "Newest", revenue = "Movie revenue"
    public var apiValue: String {
        switch self {
        case .popular: "popularity.desc"
        case .rating, .quality: "vote_average.desc"
        case .votes: "vote_count.desc"
        case .newest: "primary_release_date.desc"
        case .revenue: "revenue.desc"
        }
    }
}
public enum Feed: String, Codable, CaseIterable, Sendable {
    case discover = "Discover", recommendations = "For You", tonight = "Tonight", gems = "Hidden Gems"
    case daily = "Trending Today", weekly = "Trending This Week", releases = "Best New Releases"
    case favorites = "Favorites", watchlist = "Watchlist", watched = "Watched", rejected = "Not Interested"
    public var isLibrary: Bool { [.favorites, .watchlist, .watched, .rejected].contains(self) }
    public var flag: LibraryFlag? {
        switch self { case .favorites: .favorite; case .watchlist: .watchlist; case .watched: .watched; case .rejected: .notInterested; default: nil }
    }
    public var symbol: String {
        switch self {
        case .discover: "square.grid.2x2"; case .recommendations: "sparkles"; case .tonight: "moon.stars"
        case .gems: "diamond"; case .daily, .weekly: "chart.line.uptrend.xyaxis"; case .releases: "calendar"
        case .favorites: "heart"; case .watchlist: "bookmark"; case .watched: "checkmark.circle"; case .rejected: "hand.thumbsdown"
        }
    }
}
public struct CatalogFilter: Codable, Equatable, Sendable {
    public var media: MediaSelection = .all
    public var genre = "All genres"
    public var language = ""
    public var country = ""
    public var region = "Worldwide"
    public var fromDate = ""
    public var toDate = ""
    public var query = ""
    public var minimumRating: Double = 0
    public var minimumVotes: Int = 0
    public var maximumRuntime: Int = 0
    public var sort: SortOrder = .popular
    public var includeRestricted = false
    public var includeUnknown = false
    public var releaseWindow = "Last 30 days"
    public init() {}
    public var dateValidationMessage: String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        for value in [fromDate, toDate] where !value.isEmpty {
            guard value.count == 10, let date = formatter.date(from: value), formatter.string(from: date) == value else {
                return "Enter valid dates as YYYY-MM-DD, or leave them blank."
            }
        }
        if !fromDate.isEmpty && !toDate.isEmpty && fromDate > toDate { return "The start date must come before the end date." }
        return nil
    }
    public static let regions: [String: [String]] = [
        "Worldwide": [], "Arab World": ["EG","SA","AE","MA","DZ","TN","JO","LB","IQ","QA","KW","BH","OM","PS","SY","YE","LY","SD"],
        "India": ["IN"], "East Asia": ["JP","KR","CN","TW","HK"], "South & Southeast Asia": ["IN","PK","BD","LK","TH","VN","ID","MY","PH","SG","NP"],
        "Europe": ["GB","FR","DE","IT","ES","SE","NO","DK","FI","PL","PT","GR","IE","NL","BE","AT","CH","RO","CZ","HU"],
        "Africa": ["EG","MA","DZ","TN","NG","ZA","KE","GH","SN","ET"], "Latin America": ["MX","BR","AR","CL","CO","PE","UY","VE","CU"]
    ]
    public func allows(_ item: MediaItem) -> Bool {
        guard !item.adult, media.kinds.contains(item.kind) else { return false }
        if sort == .revenue && (item.kind == .tv || item.revenue == nil) { return false }
        let certificate = item.certification?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ["NC-17","TV-MA"].contains(certificate) { return false }
        if item.kind == .movie && certificate == "R" && !includeRestricted { return false }
        let known = item.kind == .movie ? ["G","PG","PG-13","R"] : ["TV-Y","TV-Y7","TV-Y7-FV","TV-G","TV-PG","TV-14"]
        if !known.contains(certificate) && !includeUnknown { return false }
        if genre != "All genres" && !item.genres.contains(genre) { return false }
        if !language.isEmpty && item.originalLanguage != language { return false }
        if !country.isEmpty && !item.countries.contains(country) { return false }
        if let regionCountries = Self.regions[region], !regionCountries.isEmpty, Set(item.countries).isDisjoint(with: regionCountries) { return false }
        if (!fromDate.isEmpty || !toDate.isEmpty) && item.releaseDate.isEmpty { return false }
        if !fromDate.isEmpty && item.releaseDate < fromDate { return false }
        if !toDate.isEmpty && item.releaseDate > toDate { return false }
        if item.rating < minimumRating || item.votes < minimumVotes { return false }
        if maximumRuntime > 0 && (item.runtime == nil || item.runtime! > maximumRuntime) { return false }
        if !query.isEmpty && !(item.title + " " + item.originalTitle).localizedStandardContains(query) { return false }
        return true
    }
    public mutating func setYear(_ year: Int?) {
        fromDate = year.map { "\($0)-01-01" } ?? ""
        toDate = year.map { "\($0)-12-31" } ?? ""
    }
    public func releaseDates(now: Date = Date()) -> (String, String) {
        let calendar = Calendar(identifier: .gregorian)
        let start: Date
        switch releaseWindow {
        case "Last 7 days": start = calendar.date(byAdding: .day, value: -7, to: now)!
        case "This year": start = calendar.date(from: calendar.dateComponents([.year], from: now))!
        case "Last year":
            let y = calendar.component(.year, from: now) - 1
            return ("\(y)-01-01", "\(y)-12-31")
        default: start = calendar.date(byAdding: .day, value: -30, to: now)!
        }
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return (formatter.string(from: start), formatter.string(from: now))
    }
}
public enum LibraryFlag: String, Codable, CaseIterable, Sendable {
    case favorite = "Favorite", watchlist = "Watchlist", watched = "Watched", notInterested = "Not Interested"
    public var symbol: String {
        switch self { case .favorite: "heart"; case .watchlist: "bookmark"; case .watched: "checkmark.circle"; case .notInterested: "hand.thumbsdown" }
    }
}
public struct UserLibrary: Codable, Sendable {
    public var flags: [String: Set<LibraryFlag>] = [:]
    public var ratings: [String: Int] = [:]
    public var items: [String: MediaItem] = [:]
    public var updated: [String: Date] = [:]
    public init() {}
    public func contains(_ flag: LibraryFlag, key: String) -> Bool { flags[key]?.contains(flag) == true }
    public mutating func set(_ flag: LibraryFlag, for item: MediaItem, enabled: Bool) {
        items[item.key] = item; updated[item.key] = Date()
        if enabled { flags[item.key, default: []].insert(flag) } else { flags[item.key]?.remove(flag) }
    }
    public mutating func purgeExpiredMetadata(now: Date = Date()) {
        for key in items.keys where !items[key]!.isDemo && now.timeIntervalSince(updated[key] ?? .distantPast) > 15552000 {
            items.removeValue(forKey: key); updated.removeValue(forKey: key)
        }
    }
    public mutating func normalizeKeys() {
        for oldKey in Array(items.keys) {
            guard let item = items[oldKey], oldKey != item.key else { continue }
            items[item.key] = item; items.removeValue(forKey: oldKey)
            flags[item.key, default: []].formUnion(flags.removeValue(forKey: oldKey) ?? [])
            if let value = ratings.removeValue(forKey: oldKey) { ratings[item.key] = value }
            updated[item.key] = updated.removeValue(forKey: oldKey) ?? Date()
        }
    }
}
public struct Recommendation: Sendable {
    public let item: MediaItem
    public let score: Double
    public let reason: String
}
public enum Ranking {
    public static func quality(rating: Double, votes: Int) -> Double {
        let v = Double(max(0, votes)); return (v * rating + 500 * 6.5) / (v + 500)
    }
    public static func recommendations(_ items: [MediaItem], library: UserLibrary, preferredGenre: String) -> [Recommendation] {
        var affinity: [String: Double] = [:]
        for item in library.items.values {
            let weight = library.contains(.favorite, key: item.key) ? 2.0 : (Double(library.ratings[item.key] ?? 0) >= 7 ? 1.0 : 0)
            for genre in item.genres { affinity[genre, default: 0] += weight }
        }
        if preferredGenre != "All genres" { affinity[preferredGenre, default: 0] += 2 }
        return items.filter { !library.contains(.watched, key: $0.key) && !library.contains(.notInterested, key: $0.key) }.map { item in
            let genre = item.genres.max { affinity[$0, default: 0] < affinity[$1, default: 0] }
            let boost = min(2.0, affinity[genre ?? "", default: 0] * 0.4)
            return Recommendation(item: item, score: quality(rating: item.rating, votes: item.votes) + boost,
                                  reason: boost > 0 ? "Matches your \(genre ?? "genre") taste · rating confidence considered" : "Strong audience rating balanced against vote count")
        }.sorted { $0.score == $1.score ? $0.item.key < $1.item.key : $0.score > $1.score }
    }
    public static func sorted(_ items: [MediaItem], by sort: SortOrder) -> [MediaItem] {
        items.sorted { a, b in
            let x: Double; let y: Double
            switch sort {
            case .popular: x = a.popularity; y = b.popularity
            case .rating: x = a.rating; y = b.rating
            case .quality: x = quality(rating: a.rating, votes: a.votes); y = quality(rating: b.rating, votes: b.votes)
            case .votes: x = Double(a.votes); y = Double(b.votes)
            case .revenue: x = Double(a.revenue ?? 0); y = Double(b.revenue ?? 0)
            case .newest: return a.releaseDate == b.releaseDate ? a.key < b.key : a.releaseDate > b.releaseDate
            }
            return x == y ? a.key < b.key : x > y
        }
    }
}
public enum Freshness {
    public static let interval: TimeInterval = 900
    public static func isDue(lastUpdate: Date?, now: Date = Date()) -> Bool {
        guard let lastUpdate else { return true }; return now.timeIntervalSince(lastUpdate) >= interval
    }
}
