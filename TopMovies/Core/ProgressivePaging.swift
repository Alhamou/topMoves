import Foundation

public struct PagingProgress: Sendable, Equatable {
    public let page: Int
    public let items: [MediaItem]
    public let matchedCount: Int
    public let hasMore: Bool
    public let scannedPages: Int

    public init(
        page: Int,
        items: [MediaItem] = [],
        matchedCount: Int = 0,
        hasMore: Bool = true,
        scannedPages: Int = 1
    ) {
        self.page = page
        self.items = items
        self.matchedCount = matchedCount
        self.hasMore = hasMore
        self.scannedPages = scannedPages
    }
}

public struct PagingResult: Sendable, Equatable {
    public let items: [MediaItem]
    public let page: Int
    public let hasMore: Bool
    public let updated: Date
    public let scannedPages: Int
    public let matchedCount: Int
    public let isSparse: Bool

    public init(
        items: [MediaItem],
        page: Int,
        hasMore: Bool,
        updated: Date = Date(),
        scannedPages: Int = 1,
        matchedCount: Int = 0,
        isSparse: Bool = false
    ) {
        self.items = items
        self.page = page
        self.hasMore = hasMore
        self.updated = updated
        self.scannedPages = scannedPages
        self.matchedCount = matchedCount
        self.isSparse = isSparse
    }
}

public enum ProgressivePaging {
    public typealias Result = PagingResult

    public static func fill(
        initial: [MediaItem] = [],
        startPage: Int = 1,
        targetNewMatches: Int = 20,
        maxPages: Int = 5,
        accepts: @Sendable (MediaItem) -> Bool,
        fetch: @Sendable (Int) async throws -> CatalogPage,
        publish: @Sendable (PagingProgress) async -> Void = { _ in }
    ) async throws -> PagingResult {
        guard maxPages > 0 else {
            return PagingResult(
                items: initial,
                page: max(1, startPage - 1),
                hasMore: false,
                updated: Date(),
                scannedPages: 0,
                matchedCount: 0,
                isSparse: false
            )
        }

        var accumulated = initial
        var seenKeys = Set(initial.map(\.key))
        var newMatches = 0
        var currentPage = max(1, startPage)
        var lastPage = currentPage
        var hasMore = false
        var lastUpdated = Date()
        var scannedPages = 0

        while scannedPages < maxPages {
            try Task.checkCancellation()
            let catalogPage = try await fetch(currentPage)
            scannedPages += 1
            lastPage = currentPage
            hasMore = catalogPage.hasMore
            lastUpdated = catalogPage.updated

            for item in catalogPage.items {
                if seenKeys.insert(item.key).inserted {
                    accumulated.append(item)
                    if accepts(item) {
                        newMatches += 1
                    }
                }
            }

            await publish(PagingProgress(
                page: currentPage,
                items: accumulated,
                matchedCount: newMatches,
                hasMore: hasMore,
                scannedPages: scannedPages
            ))

            if newMatches >= targetNewMatches || !catalogPage.hasMore {
                break
            }

            currentPage += 1
        }

        let isSparse = (newMatches < targetNewMatches) && hasMore

        return PagingResult(
            items: accumulated,
            page: lastPage,
            hasMore: hasMore,
            updated: lastUpdated,
            scannedPages: scannedPages,
            matchedCount: newMatches,
            isSparse: isSparse
        )
    }
}
