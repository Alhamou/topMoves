import Foundation
import Testing
@testable import TopMoviesCore

private actor PagingFixture {
    var requested: [Int] = []
    var published: [Int] = []
    let emptyUntil: Int
    let exhaustedAt: Int
    init(emptyUntil: Int, exhaustedAt: Int) { self.emptyUntil = emptyUntil; self.exhaustedAt = exhaustedAt }
    func fetch(_ page: Int) -> CatalogPage {
        requested.append(page)
        let certificate = page <= emptyUntil ? "NC-17" : "PG-13"
        let item = MediaItem(id: page, kind: .movie, title: "Page \(page)", certification: certificate)
        return CatalogPage(items: [item], hasMore: page < exhaustedAt, updated: Date(timeIntervalSince1970: Double(page)))
    }
    func publish(_ progress: PagingProgress) { published.append(progress.page) }
}

private actor RealisticCatalogFixture {
    var requested: [Int] = []
    let matchesPerPage: Int
    let totalItemsPerPage: Int
    let exhaustedAt: Int

    init(matchesPerPage: Int, totalItemsPerPage: Int = 20, exhaustedAt: Int = 50) {
        self.matchesPerPage = matchesPerPage
        self.totalItemsPerPage = totalItemsPerPage
        self.exhaustedAt = exhaustedAt
    }

    func fetch(_ page: Int) -> CatalogPage {
        requested.append(page)
        var items: [MediaItem] = []
        for i in 0..<totalItemsPerPage {
            let id = page * 1000 + i
            let isMatch = i < matchesPerPage
            let cert = isMatch ? "PG-13" : "NC-17"
            items.append(MediaItem(id: id, kind: .movie, title: "Film \(id)", certification: cert))
        }
        return CatalogPage(items: items, hasMore: page < exhaustedAt, updated: Date(timeIntervalSince1970: Double(page)))
    }
}

@Test func filteredEmptyPagesContinueUntilMatchingPostersAreFound() async throws {
    let fixture = PagingFixture(emptyUntil: 2, exhaustedAt: 8)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(initial: [], startPage: 1, targetNewMatches: 1, maxPages: 4,
        accepts: { filters.allows($0) }, fetch: { await fixture.fetch($0) }, publish: { await fixture.publish($0) })
    #expect(await fixture.requested == [1, 2, 3])
    #expect(await fixture.published == [1, 2, 3])
    #expect(result.items.filter { filters.allows($0) }.count == 1)
    #expect(result.page == 3 && result.hasMore)
}

@Test func emptyMatchingResultsNeverCauseUnboundedRequests() async throws {
    let fixture = PagingFixture(emptyUntil: 100, exhaustedAt: 500)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(initial: [], startPage: 1, targetNewMatches: 24, maxPages: 3,
        accepts: { filters.allows($0) }, fetch: { await fixture.fetch($0) }, publish: { await fixture.publish($0) })
    #expect(await fixture.requested == [1, 2, 3])
    #expect(result.page == 3 && result.hasMore)
}

@Test func providerExhaustionStopsEvenWhenNoTitleMatches() async throws {
    let fixture = PagingFixture(emptyUntil: 100, exhaustedAt: 2)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(initial: [], startPage: 1, targetNewMatches: 24, maxPages: 5,
        accepts: { filters.allows($0) }, fetch: { await fixture.fetch($0) }, publish: { await fixture.publish($0) })
    #expect(await fixture.requested == [1, 2])
    #expect(!result.hasMore)
}

@Test func appendPagingDoesNotDuplicateExistingTitles() async throws {
    let fixture = PagingFixture(emptyUntil: 0, exhaustedAt: 8)
    let existing = MediaItem(id: 1, kind: .movie, title: "Existing", certification: "PG-13")
    let result = try await ProgressivePaging.fill(initial: [existing], startPage: 1, targetNewMatches: 1, maxPages: 3,
        accepts: { _ in true }, fetch: { await fixture.fetch($0) }, publish: { _ in })
    #expect(result.items.count == 2)
    #expect(result.page == 2)
}

@Test func reproSparseFirstPageWithOnlyTwoMatchesAutofillsUntilTargetReached() async throws {
    // Concrete repro test: each provider page yields 20 titles, but after conservative filtering only 2 match.
    // Progressive autofill must not stop after page 1 (which would only show 2 titles to the user);
    // it must automatically fetch successive pages until targetNewMatches (here, 6) is reached.
    let fixture = RealisticCatalogFixture(matchesPerPage: 2, totalItemsPerPage: 20, exhaustedAt: 20)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(
        initial: [],
        startPage: 1,
        targetNewMatches: 6,
        maxPages: 5,
        accepts: { filters.allows($0) },
        fetch: { await fixture.fetch($0) }
    )
    #expect(await fixture.requested == [1, 2, 3])
    #expect(result.items.filter { filters.allows($0) }.count == 6)
    #expect(result.page == 3)
    #expect(result.hasMore)
    #expect(!result.isSparse)
}

@Test func pagesYieldingZeroAllowedItemsDoNotPrematurelyEndAvailableResults() async throws {
    // Pages 1 and 2 return 0 allowed items under current conservative filters.
    // When bounded maxPages is reached, hasMore MUST remain true so available results are not prematurely ended.
    let fixture = RealisticCatalogFixture(matchesPerPage: 0, totalItemsPerPage: 20, exhaustedAt: 10)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(
        initial: [],
        startPage: 1,
        targetNewMatches: 10,
        maxPages: 2,
        accepts: { filters.allows($0) },
        fetch: { await fixture.fetch($0) }
    )
    #expect(await fixture.requested == [1, 2])
    #expect(result.items.filter { filters.allows($0) }.isEmpty)
    #expect(result.page == 2)
    #expect(result.hasMore)
    #expect(result.isSparse)
}

@Test func subsequentPagingAfterZeroAllowedItemsResumesFromNextPage() async throws {
    // Pages 1 and 2 yielded 0 allowed items. Next fetch starting at page 3 finds matching items.
    let fixture = RealisticCatalogFixture(matchesPerPage: 3, totalItemsPerPage: 20, exhaustedAt: 10)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(
        initial: [],
        startPage: 3,
        targetNewMatches: 3,
        maxPages: 2,
        accepts: { filters.allows($0) },
        fetch: { await fixture.fetch($0) }
    )
    #expect(await fixture.requested == [3])
    #expect(result.items.filter { filters.allows($0) }.count == 3)
    #expect(result.page == 3)
    #expect(result.hasMore)
}

@Test func sparseResultsFlagCommunicatesWhenFilteredResultsStaySparse() async throws {
    // Provider yields only 1 match per page, with maxPages capped at 3. Target is 10.
    let fixture = RealisticCatalogFixture(matchesPerPage: 1, totalItemsPerPage: 20, exhaustedAt: 10)
    let filters = CatalogFilter()
    let result = try await ProgressivePaging.fill(
        initial: [],
        startPage: 1,
        targetNewMatches: 10,
        maxPages: 3,
        accepts: { filters.allows($0) },
        fetch: { await fixture.fetch($0) }
    )
    #expect(await fixture.requested == [1, 2, 3])
    #expect(result.items.filter { filters.allows($0) }.count == 3)
    #expect(result.isSparse)
    #expect(result.hasMore)
}
