# TopMovies — approved implementation contract

Native SwiftUI macOS 14+ app. English-only interface, en-US metadata, worldwide MOVIES AND TV series. Mobile is deferred until the user reviews the Mac app and separately requests mobile. No paid services, AI/ML integration, account backend or publication.

Discovery: upright 2:3 poster grid, genres using separate movie/TV taxonomies, All/Movies/TV Shows, original language, origin country/region presets, year/date range, minimum audience rating/votes, duration, sorting and search. Restore last filters/sort. Trending day/week is separate from highest-rated releases. Movie revenue means lifetime reported revenue, never weekly box office; series release windows mean first-air dates.

Details: US content certificate + country, audience score and votes before trailers; unavailable critic score honestly marked; synopsis, original title/language, countries, cast/crew, multiple supported trailers. TV adds status, seasons/episodes.

Conservative defaults: exclude adult=true, NC-17 and TV-MA; hide R unless enabled; unknown US certificates hidden unless revealed. Never infer US certification from another country, numeric ages from R/TV-MA, safety from absence, episode safety from series certification, or worldwide exhibition bans. Apply policy to discovery/recommendations/saved browsing.

Library: Favorites, Watchlist, Watched, Not Interested, personal rating. Explainable traditional rules using genre affinity and Bayesian rating quality. Exclude watched/rejected recommendations. Tonight requires known runtime. Lesser-known quality is explicitly ranked within fetched candidates.

Freshness: refresh launch/foreground and every 15 minutes while active if due; no updates promised while closed. Cancel/coalesce requests, max four concurrent detail requests, respect Retry-After. Cache for speed/offline; show timestamps/stale/errors. Preserve filters/library. Metadata cache expiry within provider limits; credentials in Keychain. No token means labeled fictional demo with original native poster illustrations, not fake live results.

Architecture: Foundation core in TopMovies/Core, main-actor app state and Keychain in TopMovies/App, SwiftUI views in TopMovies/Views. No third-party packages. Checked-in Xcode project generator, Swift Testing unit/integration fixtures.

Commands: swift test; xcodebuild -project TopMovies.xcodeproj -scheme TopMovies -destination 'platform=macOS' -derivedDataPath build/mac CODE_SIGNING_ALLOWED=NO build. Verify actual Mac launch/UI and core certificate/filter/ranking/date/persistence/freshness/transport checks. Live authenticated testing requires user-supplied TMDB token.

Design: English LTR, charcoal, restrained amber, native sidebar, scalable system fonts, keyboard accessibility, no autoplay. Never commit credentials or use production administrative shells.
