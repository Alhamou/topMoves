# Contributing to TopMovies

Thank you for your interest in contributing to **TopMovies**! We welcome contributions from developers, designers, and testers of all backgrounds.

---

## Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please be courteous, respectful, and collaborative.

---

## Ways to Contribute

1. **Reporting Bugs**: Find a glitch, edge case, or UI bug? Let us know!
2. **Suggesting Enhancements**: Propose new filters, views, or platform support (e.g., iOS/iPadOS).
3. **Submitting Pull Requests**: Implement bug fixes, performance improvements, or new features.
4. **Documentation**: Clarify setup steps, write guides, or improve inline comments.

---

## Development Setup

### Prerequisites

- **macOS Sonoma (14.0)** or later.
- **Xcode 15.0+** with the **Swift 6.0** toolchain.
- Git.
- Optional: A free, non-commercial [TMDB API Read Access Token](https://www.themoviedb.org/settings/api) for live testing. (The app functions completely offline in Demo Mode without a token).

### Getting the Code

```bash
git clone https://github.com/your-username/topMovies.git
cd topMovies
```

### Running Tests

We value test coverage and regression protection. Always make sure tests pass before opening a PR:

```bash
swift test
```

### Building the macOS App

You can open `TopMovies.xcodeproj` in Xcode and press `Cmd + R`, or build and launch from the command line:

```bash
./scripts/run-mac.sh
```

---

## Project Architecture & Principles

- **Zero External Third-Party Dependencies**: The app is built using purely native Apple frameworks (`SwiftUI`, `AppKit`, `Security`, `Combine`, `Foundation`). Keep external dependencies to a strict zero.
- **Swift 6 & Strict Concurrency**: All code must conform to modern Swift concurrency standards (`@MainActor`, `Sendable`, structured concurrency).
- **Privacy First & Sandboxing**: Network access must be restricted to user-configured APIs. Personal preferences and bookmarks never leave the user's Mac. Secrets (like the TMDB token) are stored strictly in the macOS Keychain (`Security.framework`) and must never be logged or exposed.
- **Deterministic Content & Filtering**: Content filtering (e.g., adult content exclusions, certifications) must adhere to the conservative safety policies outlined in [README.md](README.md#content-policy--attribution).

For a deep dive into the internal data flow, state management, and caching layers, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Pull Request Guidelines

1. **Fork & Branch**: Create a feature branch off `main` with a descriptive name (e.g., `feature/custom-sorting`, `fix/detail-layout-truncation`).
2. **Follow Code Style**:
   - Write clean, idiomatic Swift.
   - Use meaningful variable and function names.
   - Keep views modular and decompose complex view bodies into smaller components.
3. **Include Tests**: Add tests in `Tests/TopMoviesCoreTests/` covering your changes, edge cases, and regression risks.
4. **Run the Test Suite**: Verify that `swift test` passes completely with zero errors.
5. **Open a PR**: Fill out the [Pull Request Template](.github/pull_request_template.md) detailing the changes made, the rationale, and testing steps.

---

## Reporting Issues

Before opening a new issue:
- Check existing issues to verify if the issue or feature is already being tracked.
- Use our [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md) or [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md).
- Never share sensitive credentials, API tokens, or personal logs containing private information.
