# Provider decision — researched 8 October 2026

**TMDB** covers movies/TV, distinct genres, English metadata, original language/countries, audience score/votes, posters, movie US release certificates, TV country content ratings, credits, videos, TV seasons/episodes, movie revenue and daily/weekly interest trends. It is the chosen provider, conditional on the developer's approved noncommercial account/token and terms. Not all fields/languages/countries have complete coverage.

Official references:
- [FAQ, free noncommercial access and attribution](https://developer.themoviedb.org/docs/faq)
- [API terms: commercial agreement, attribution, cache restrictions, AI/ML restrictions](https://www.themoviedb.org/api-terms-of-use?language=en-CA)
- [Bearer authentication](https://developer.themoviedb.org/docs/authentication-application)
- [Movie discovery](https://developer.themoviedb.org/reference/discover-movie), [TV discovery](https://developer.themoviedb.org/reference/discover-tv)
- [Movie certificates by release/country](https://developer.themoviedb.org/reference/movie-release-dates), [TV content ratings](https://developer.themoviedb.org/reference/tv-series-content-ratings)
- [Movie details/revenue](https://developer.themoviedb.org/reference/movie-details), [TV details](https://developer.themoviedb.org/reference/tv-series-details), [season details](https://developer.themoviedb.org/reference/tv-season-details)
- [Movie videos](https://developer.themoviedb.org/reference/movie-videos), [TV videos](https://developer.themoviedb.org/reference/tv-series-videos)
- [Trending semantics](https://developer.themoviedb.org/docs/popularity-and-trending)
- [Image URL construction](https://developer.themoviedb.org/docs/image-basics)
- [Approved logos/branding](https://www.themoviedb.org/about/logos-attribution)

TMDB is closed-source/free noncommercial API access, **not genuinely open licensed data**. Its terms prohibit caching beyond six months, restrict derivatives and use with AI/ML applications. Code never trains a model or sends catalog data to AI. Traditional filtering/arithmetic recommendations do not represent permission to introduce AI later. Review permission with TMDB before any such expansion or commercial launch.

`TopMovies/Resources/TMDB.svg` was retrieved from TMDB's approved **Primary long (blue)** asset:
https://www.themoviedb.org/assets/v4/logos/v2/blue_long_2-9665a76b1ae401a510ec1e0ca40ddcb3b0cfe45f1d51b77a308fea0845885648.svg
`TMDB.png` is a lossless raster rendering with the same aspect ratio/colors for native display. This mark remains TMDB's; no MIT relicensing or endorsement. Generic SF Symbols (shield, star, playback) are interface concepts, not altered provider logos. Trailer host names identify the real host; no invented translation/subtitle provider badge.

**Critic scores:** no suitable universally free authorized integration was established. [Rotten Tomatoes licensing](https://www.rottentomatoes.com/help_desk/licensing) requires a proposed-usage request. [OMDb](https://www.omdbapi.com/) advertises CC BY-NC and [1,000 requests/day free keys](https://www.omdbapi.com/apikey.aspx), but [its terms](https://www.omdbapi.com/legal.htm) and third-party rating ownership do not establish blanket permission to republish critic scores. Hence an honest unavailable state; no scraping, invented stars or relabeled TMDB score.

**Alternative data:** [Wikidata structured data is CC0](https://www.wikidata.org/wiki/Wikidata:Licensing), but this does not license linked posters/trailers and does not provide a uniformly complete audience rating/certification/video discovery feed for this app. [IMDb noncommercial datasets](https://data.imdb.com/non-commercial-datasets/) contain rating/genre data under restrictions, not the poster/trailer/country-certification feed needed here. Neither is a substitute for all requirements.

**Box office:** TMDB has a reported movie revenue field and revenue sorting. It does not establish weekly theatrical receipts, completeness, currency-normalized profit or ticket counts. [Box Office Mojo terms](https://www.boxofficemojo.com/article/ed997786628/) prohibit automated scraping absent express consent; no scraping integration.

**Suitability:** [MPA film labels/descriptors](https://www.filmratings.com/ratings-guide/) and [TV Parental Guidelines](https://www.tvguidelines.org/ratings.html) are different systems. TV labels can differ per episode and version. `include_adult=false` alone is insufficient. This app additionally checks actual returned US labels and hides unknowns by default. No complete global banned-title registry, reliable scene-level content advisory feed or identified subtitle/translation provider was verified.
