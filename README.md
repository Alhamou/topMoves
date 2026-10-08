# TopMovies for Mac

A native SwiftUI movie **and TV series** discovery app. English-only interface and English metadata where supplied, worldwide catalog, US content certificates by default. The current deliverable is **macOS only**. Mobile is deferred until the desktop version is reviewed and separately requested.

## Open the app

The review build is at `build/TopMovies.app`. Open it in Finder, or:

```sh
open /Users/alhamou/Developer/topMovies/build/TopMovies.app
```

macOS 14 or later is required. On another Mac, build it locally using Xcode; this local review app is ad-hoc signed, not notarized or an App Store release.

## Build and run

Open `TopMovies.xcodeproj`, select the **TopMovies** scheme and **My Mac**, and Run. No external packages or paid tools are needed. To reproduce the standalone review app:

```sh
./scripts/run-mac.sh
```

This builds Release, copies the app to `build/TopMovies.app`, signs it locally with its sandbox/network entitlements, and opens it. For an unsigned development build:

```sh
xcodebuild -project TopMovies.xcodeproj -scheme TopMovies -destination 'platform=macOS' -derivedDataPath build/mac CODE_SIGNING_ALLOWED=NO build
swift test
```

`python3 scripts/generate_project.py` regenerates the checked-in Xcode project after adding source files. Original app icon generation is optional: `swift scripts/make_icon.swift "$PWD"`, followed by `iconutil -c icns build/TopMovies.iconset -o TopMovies/Resources/AppIcon.icns`.

## Connect real data

1. Create a TMDB account, apply for free **noncommercial** API access and accept the provider's terms yourself: <https://www.themoviedb.org/settings/api>.
2. Copy the **API Read Access Token**, not the short API key.
3. In TopMovies, open **Settings & Sources** (⌘,), paste into the secure field and choose **Save & Connect**.

The token is kept in macOS Keychain, never in source, snapshots or logs. **Do not send secrets in chat.** Removing it returns to demo mode. The real API has not been authenticated/tested in this workspace because no valid token was supplied. HTTP decoding, errors, caching and rate-limit behavior are tested with fixtures; live content completeness and trailer playback need verification after connection.

Without a token the entire catalog is **fictional illustrative demo content**: titles, summaries, cast, scores, votes, certificates, episode information and revenue. Posters are original native geometric illustrations. There are no real trailers for fictional titles. Demo bookmarks have a separate namespace and cannot become live-provider bookmarks.

## Use it

- Browse **Discover** by genre, or **For You**, **Tonight**, **Hidden Gems**, daily/weekly trending and **Best New Releases**.
- Choose **All / Movies / TV Shows**. **Filters** includes language, region collections, countries, date range/year/decade, minimum score/votes, time limit and conservative content settings. Last filters/sort/search restore automatically. Origin language is independent of display language. Region collections are explicitly curated country groupings, not exhaustive geopolitical definitions.
- Click a poster for US classification and audience score/votes **before** trailers, story, original title/language, country context, cast/crew, reported movie revenue or TV seasons/episodes. Unknown fields stay visibly unavailable.
- Save **Favorite**, **Watchlist**, **Watched**, **Not Interested**, and a personal 1–10 rating. Right-click a poster for quick actions. Library and preferences are local to this Mac. Content filters apply to saved items too.
- ⌘F searches; ⌘R refreshes; ⇧⌘F toggles filters; ⇧⌘0 resets them; Escape closes details/settings. Native controls support keyboard navigation (enable macOS Keyboard Navigation to Tab through all controls).
- **Tonight** uses known runtimes, defaults to 120 minutes and excludes watched titles. **Hidden Gems** means rating ≥7 and 100–3,000 votes among loaded candidates. **For You** uses ordinary arithmetic rules and gives an explanation; it is not AI/ML.

## Freshness and scope

Catalogs refresh at launch/foreground when due and every 15 minutes **while active**. No real-time feed or updates while closed are promised. Provider freshness determines actual accuracy. Refresh preserves your filters/library. Requests debounce, cancel/coalesce, bound detail concurrency to four and back off on HTTP 429. One page loads up to 20 titles per media type; additional posters use explicit lightweight pagination. Conservative filtering can leave a page empty: broaden filters or load more.

Catalog snapshots/posters expire after 7 days; detail/season/video responses are reused up to 6 hours. Cached results retain their fetch timestamp, and failed refreshes show saved/stale data with an error rather than presenting it as current. Library provider metadata expires within 180 days; personal flags/ratings remain and saved IDs can be fetched again. Token removal does not delete your personal library. Clear Provider Cache is available in Settings.

Trending is provider attention activity, **not** a best-rating chart. Best New Releases means movie release dates / series **first-air** dates within the selected window, ordered by current audience scores with ≥50 votes. It does not mean ratings collected exclusively during that period, newly airing seasons, or best new episodes. Confidence/recommendation/gem ordering is local to loaded candidates. Mixed movie/TV results use their own provider taxonomies.

Revenue is TMDB's reported total in USD where available, not profit, inflation-adjusted revenue or weekly/monthly box office; values may be absent/incomplete. No subtitle-download or exhibition-ban registry integration is included. Critic scores are explicitly unavailable: TMDB scores are audience votes. English metadata does not identify a translator or subtitle company. Trailers list English and original-language entries where returned; YouTube supports click-to-load embedded playback or opening the host, Vimeo opens its host. Host/uploader/region restrictions can prevent playback.

## Content policy and rights

Explicit/adult-flagged titles, NC-17 and TV-MA are excluded. R movies are hidden unless enabled. Unknown US labels are hidden unless deliberately revealed; absence is not safety. R/TV-MA are not mapped to numeric 18+ cutoffs. US film G/PG/PG-13/R/NC-17 and TV labels are separate. Series-level classifications do not certify every episode/version. No promise excludes every extreme scene; no worldwide exhibition-ban coverage is claimed.

TMDB is free for **noncommercial** use with attribution, not an open-data license. Commercial use needs a separate written agreement. API media remains subject to rightsholders' rights. TMDB terms restrict AI/ML uses; this app does not train/use AI and uses deterministic preference rules. See [source research](docs/DATA_SOURCES.md). Approved TMDB logo and required notice appear in Settings and live pages; no endorsement is implied.

Application code and original demo art: MIT. TMDB logo/media, Apple frameworks and external host content are **not** covered by this repository's MIT license. See [verification](docs/VERIFICATION.md) for exactly what was tested and remaining limits.
