# TopMovies Architecture & Design Guide

This document outlines the architectural patterns, state management, and data flow of **TopMovies for Mac**.

---

## High-Level Architecture Overview

TopMovies is designed with **zero third-party dependencies**, utilizing pure native Apple frameworks (`SwiftUI`, `AppKit`, `Foundation`, `Security`). The app is split into two layers:

1. **TopMoviesCore (`Package.swift`)**:
   - Platform-agnostic domain models, TMDB API client, offline demo catalogs, and progressive pagination algorithms.
   - Built to be easily shared between macOS and future iOS/iPadOS clients.
2. **TopMovies Mac App (`TopMovies.xcodeproj`)**:
   - Native macOS SwiftUI views, sidebar navigation, keyboard shortcuts, window toolbars, and keychain integration.

```
┌────────────────────────────────────────────────────────┐
│                   TopMovies Mac App                    │
│   (SwiftUI Navigation, Sidebars, Details, Settings)    │
└───────────────────────────┬────────────────────────────┘
                            │ Environment & Bindings
┌───────────────────────────▼────────────────────────────┐
│                       AppStore                         │
│  (Observable State, Filtering, Local Library, Cache)   │
└─────────────┬───────────────────────────┬──────────────┘
              │                           │
  Token Configured?             No Token?
              │                           │
┌─────────────▼─────────────┐ ┌───────────▼──────────────┐
│        TMDBClient         │ │       DemoCatalog        │
│  (Live API, Rate Limiting,│ │  (Offline Illustrations, │
│   Caching, HTTP Decoders) │ │   Deterministic Data)    │
└───────────────────────────┘ └──────────────────────────┘
```

---

## Core Components

### 1. State Management (`TopMovies/App/AppStore.swift`)
- Single source of truth for the application's runtime state.
- Manages user library records (*Favorites*, *Watchlist*, *Watched*, *Not Interested*, ratings) persisted locally to `UserDefaults`.
- Coordinates catalog queries, active filters, search inputs, and debounce timers.
- Manages credentials in the macOS Keychain (`Security.framework`).

### 2. Networking & TMDB API (`TopMovies/Core/TMDBClient.swift`)
- Communicates directly with TMDB API v3 over HTTPS.
- Employs strict request debouncing and request coalescing to prevent race conditions.
- Automatic rate-limit handling: backs off smoothly on HTTP `429 Too Many Requests`.
- Detail concurrency is bounded to 4 parallel workers.
- Caching layer:
  - Catalog responses and posters cached up to 7 days.
  - Video and season metadata cached up to 6 hours.
  - In-flight failure falls back gracefully to stale cache with clear error indicators.

### 3. Progressive Pagination (`TopMovies/Core/ProgressivePaging.swift`)
- Designed to solve sparse result sets caused by conservative content filtering.
- Automatically fetches subsequent pages until a minimum number of valid posters are matched or catalog exhaustion is reached.
- Protects against infinite loops with bounding logic and duplicate deduplication.

### 4. Offline Demo Mode (`TopMovies/Core/DemoCatalog.swift`)
- Provides a rich, fully populated mock catalog out-of-the-box.
- Generates procedural geometric poster art without requiring any network connection.
- Strict isolation: Demo bookmarks and ratings occupy a distinct namespace and cannot collide with live TMDB identifiers.

---

## Security & Privacy Model

- **App Sandbox**: Fully sandboxed with network client entitlement only (`com.apple.security.network.client`).
- **Keychain Storage**: API tokens are saved in macOS Keychain with access controls ensuring only the TopMovies application can read them.
- **Zero Telemetry**: No third-party analytics, tracking SDKs, or external monitoring services are embedded.
