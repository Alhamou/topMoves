# Verification — 8 October 2026

## Delivered artifact

`build/TopMovies.app` is a local Release build, ad-hoc signed with app-sandbox and outgoing-network entitlements. Code-signature verification succeeded. The binary contains **arm64 and x86_64** slices, targets macOS 14+, and was launched locally on Apple Silicon. It is not notarized or published. No iOS target was created or built, as requested.

## Automated checks

- `swift test`: **19 Swift Testing tests passed**, zero failures. XCTest's separate empty wrapper reports 0 tests; the actual Swift Testing runner reports 19.
- Development macOS build: passed.
- Final universal Release build: passed using Xcode 26.2 / Swift 6 with both architectures.
- `codesign --verify --deep --strict --verbose=2 build/TopMovies.app`: passed.
- No Swift compiler errors/warnings remained. Xcode's metadata processor emits its standard warning that AppIntents metadata extraction is skipped because this app has no AppIntents dependency.
- Mutation check: temporarily inverted the adult exclusion; the certification test failed with four issues. Restored the source before the final passing tests/build.

Tests cover conservative movie/TV certificate policy; unknown and explicit content handling; movie/TV/demo identity separation; search/language/region/date intersections; impossible dates; tiny vote samples versus broad consensus; recommendation exclusions; persisted filter/library JSON round-trip; metadata expiry retaining personal flags; full saved-ID restoration; trailer validation/deduplication/official priority; refresh due boundaries; 401 errors; 429 backoff; detail cache reuse; TV season/certificate decoding; vote-count ordering and missing revenue.

## Actual native UI checks

Using the running app's accessibility tree and screenshots:

- Inspected the upright poster grid, dark layout, sidebar, source/demo notice, audience-score indicators and movie details.
- Opened The Last Observatory (fictional), added Favorite and Watchlist, selected a personal 8/10 score, and verified Favorites contains the title.
- Switched to TV Shows: four illustrative series, distinct TV genre options, movie-only genres absent.
- Opened Signals from Home: TV-14 clearly separate from film labels, first-season list with eight episodes, expanded an episode synopsis.
- Relaunched the Release app and verified the last TV media filter restored.
- Opened Filters; enabling R and unknown disclosure increased the all-media demo result count from 13 to 15. Reset the filters afterward.
- Added explicit accessible saved/not-saved values and refined long poster-title typography after initial screenshot review.

## Honest remaining limits

- **No valid TMDB token was supplied. Authenticated live catalog/search/trending/revenue requests and real trailer playback were not verified.** Transport decoding/error/caching paths were exercised with local fixtures. Enter the user's token in the app's Settings secure field, not in chat.
- Keychain save/remove and YouTube embedding are implemented but were not fully exercised through the UI. A capture/control issue appeared while trying to inspect Settings: repeated `Sky Computer Use native pipe closed before response` errors. The app remained running; a one-second process sample showed the main thread idle in the normal AppKit event loop, not hung in application code.
- Actual grid/details screenshots were displayed inline during early native verification, but **a local screenshot artifact could not be saved** because the native capture connection repeatedly closed. No screenshot was fabricated. The final application was relaunched for review; final UI capture could not be reconfirmed after the tool disconnection.
- Refresh interval arithmetic, caching and error policy have tests; no full 15-minute active-refresh soak or disconnected-network end-to-end test was performed. Data completeness and certificate/video coverage remain provider-dependent.
- Runtime checks were on Apple Silicon; Intel is build-verified, not runtime-tested. No accessibility certification or exhaustive keyboard/VoiceOver audit is claimed.

## Scope and privacy

No production SSH/admin access, no App Store publication, no paid dependencies/services, no account creation or acceptance of provider terms was performed. UI fixtures are fictional, source restrictions are recorded in DATA_SOURCES.md, and mobile is deferred pending desktop review.
