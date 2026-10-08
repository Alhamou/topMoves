# Changelog

All notable changes to **TopMovies** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- iOS / iPadOS native interface support.
- Custom user-created lists.
- Additional language metadata support.

---

## [0.1.0] - 2026-10-08

### Added
- **Native macOS SwiftUI Experience**: Built exclusively for macOS 14+ Sonoma with native navigation, glassmorphism, and responsive grid layouts.
- **Discover & Curated Views**:
  - Browse movies and TV series across all TMDB genres.
  - Dedicated sections: *Discover*, *For You*, *Tonight*, *Hidden Gems*, *Trending*, and *Best New Releases*.
- **Advanced Filtering Engine**:
  - Filter by media type (All / Movies / TV Shows), release dates, rating ranges, vote counts, runtime limits, and original languages.
  - Region-specific collections and conservative content rating filters.
- **Progressive Paging**:
  - Automatic autofill pagination for sparse filter results.
  - Smooth infinite scrolling with concurrency throttling and duplicate elimination.
- **Complete Offline Demo Mode**:
  - Fully featured fictional catalog with original illustrations, summaries, and ratings when no API token is supplied.
- **Secure Keychain Storage**:
  - TMDB API Read Access Tokens are stored safely in macOS Keychain with zero leakage risks.
- **Local Personal Library**:
  - Bookmarking for *Favorites*, *Watchlist*, *Watched*, *Not Interested*, and personal 1–10 star ratings.
- **High-Resolution macOS Icon**:
  - Modern Big Sur / Sonoma squircle app icon and cinematic branding assets.
- **Comprehensive Test Suite**:
  - 27 unit and integration tests covering caching, progressive paging, content moderation, date validation, and credentials.
