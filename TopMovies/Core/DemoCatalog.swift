import Foundation

public enum DemoCatalog {
    // Entirely fictional titles, ratings, certifications and cast. Never presented as provider data.
    public static let items: [MediaItem] = [
        make(1, "The Last Observatory", "A night-shift astronomer receives a signal that seems to predict tomorrow. A quiet mystery about curiosity, memory, and the sky we share.", "2026-10-02", "en", ["GB"], ["Science Fiction", "Drama"], 8.4, 3200, 112, "PG-13"),
        make(2, "Letters from Kyoto", "Two strangers exchange letters through a forgotten postbox, tracing a friendship across seasons and the streets of Kyoto.", "2024-04-19", "ja", ["JP"], ["Drama", "Romance"], 8.2, 1800, 104, "PG"),
        make(3, "A Thousand Small Days", "A family-run bakery becomes the meeting place for an unexpected community, one recipe and one gentle disagreement at a time.", "2026-09-18", "hi", ["IN"], ["Comedy", "Drama"], 7.8, 2600, 118, "PG"),
        make(4, "The Quiet Floor", "An architect discovers a room missing from every blueprint. The building's history offers clues, but each answer opens another door.", "2024-10-11", "en", ["US"], ["Horror", "Mystery"], 7.6, 4100, 96, "PG-13"),
        make(5, "Beyond the Dunes", "A cartographer and a musician cross the desert to record disappearing songs, discovering the stories hidden between landmarks.", "2023-08-17", "ar", ["EG", "MA"], ["Adventure", "Drama"], 8.1, 950, 109, "PG"),
        make(6, "Blue Hour Express", "On the last train of the evening, a misplaced case brings together three passengers who have very different reasons to find its owner.", "2025-02-14", "ko", ["KR"], ["Thriller", "Crime"], 8.0, 5100, 102, "PG-13"),
        make(7, "Sunday in Lisbon", "A lost dog sends two neighbors on an unexpectedly funny journey through the city, reshaping their plans for an ordinary Sunday.", "2024-07-05", "pt", ["PT"], ["Comedy"], 7.7, 700, 89, "PG"),
        make(8, "The Floating Garden", "A young inventor builds a garden above a crowded city, learning that the best ideas need a little help from everyone.", "2025-05-23", "fr", ["FR"], ["Animation", "Family"], 8.3, 2200, 86, "G"),
        make(9, "Signals from Home", "A radio repair shop connects the lives of a coastal town. Each season follows a new voice and a mystery that belongs to everyone.", "2024-03-01", "ar", ["LB"], ["Drama", "Mystery"], 8.5, 3100, 44, "TV-14", .tv),
        make(10, "The Atlas Society", "Five researchers investigate forgotten maps and the people who drew them, balancing fieldwork, friendship, and competing ideas.", "2026-09-25", "en", ["GB", "CA"], ["Action & Adventure", "Drama"], 8.1, 4600, 48, "TV-14", .tv),
        make(11, "City of Paper", "A small newsroom tries to keep a neighborhood informed as its reporters discover that every ordinary street has an extraordinary story.", "2023-11-02", "es", ["MX"], ["Comedy", "Drama"], 7.9, 1600, 28, "TV-PG", .tv),
        make(12, "Monsoon Sketchbook", "An artist returns to her hometown during the rains, documenting the lives of friends she thought she knew.", "2025-07-18", "ta", ["IN"], ["Drama"], 8.0, 640, 42, "TV-PG", .tv),
        make(13, "A River Remembers", "A boat maker follows an old river route, discovering a changing landscape and the traditions that endure along its banks.", "2022-06-03", "zh", ["CN"], ["Documentary"], 8.2, 560, 92, "PG"),
        make(14, "Midnight Archive", "A conservator uncovers an unsettling recording in an abandoned archive. This fictional sample demonstrates the optional R filter.", "2024-09-20", "en", ["US"], ["Horror", "Thriller"], 7.5, 1500, 108, "R"),
        make(15, "Uncharted Morning", "A fictional sample with no US certificate demonstrates how unknown classifications are hidden by default.", "2025-03-10", "it", ["IT"], ["Drama"], 7.9, 800, 100, nil)
    ]
    private static func make(_ id: Int, _ title: String, _ overview: String, _ date: String, _ language: String, _ countries: [String], _ genres: [String], _ rating: Double, _ votes: Int, _ runtime: Int, _ certificate: String?, _ kind: MediaKind = .movie) -> MediaItem {
        MediaItem(id: id, kind: kind, title: title, originalTitle: title, overview: overview, releaseDate: date,
                  originalLanguage: language, countries: countries, genres: genres, rating: rating, votes: votes,
                  popularity: Double(200 - id * 7), runtime: runtime, certification: certificate,
                  revenue: kind == .movie ? id * 1230000 : nil, status: kind == .tv ? "Returning Series" : "Released",
                  cast: [Person(id: id * 10, name: "Alex Morgan", role: "Lead (fictional)"), Person(id: id * 10 + 1, name: "Sam Rivers", role: "Supporting (fictional)")],
                  crew: [Person(id: id * 20, name: "Jamie Lee", role: kind == .tv ? "Creator (fictional)" : "Director (fictional)")],
                  seasons: kind == .tv ? [Season(id: id * 100, number: 1, name: "Season 1", episodeCount: 8, airDate: date, overview: "An illustrative eight-episode season.")] : [], isDemo: true)
    }
}
