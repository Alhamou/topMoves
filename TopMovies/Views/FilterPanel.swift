import SwiftUI

struct FilterPanel: View {
    @Bindable var store: AppStore
    private var languages: [String: String] {
        var values = ["": "Any original language"]
        for language in Locale.LanguageCode.isoLanguageCodes {
            let code = language.identifier
            guard code.count == 2 else { continue }
            values[code] = Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? code
        }
        return values
    }
    private var countries: [(String, String)] {
        Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            guard code.count == 2, let name = Locale(identifier: "en_US").localizedString(forRegionCode: code) else { return nil }
            return (code, name)
        }.sorted { $0.1 < $1.1 }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Refine your discovery", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Text("Automatically saved").font(.caption).foregroundStyle(.secondary)
                Button("Reset") { store.filters = CatalogFilter() }.buttonStyle(.link)
                Button { store.showFilters = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Close filters")
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Original language", selection: $store.filters.language) {
                        ForEach(languages.keys.sorted { languages[$0]! < languages[$1]! }, id: \.self) { Text(languages[$0]!).tag($0) }
                    }
                    Picker("Region collection", selection: $store.filters.region) {
                        ForEach(CatalogFilter.regions.keys.sorted(), id: \.self) { Text($0) }
                    }
                    Picker("Origin country", selection: $store.filters.country) {
                        Text("Any country").tag("")
                        ForEach(countries, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Minimum age rating", selection: $store.filters.minimumAge) {
                        ForEach(AgeRating.allCases, id: \.self) { rating in
                            Text(rating.title).tag(rating)
                        }
                    }
                    Text("Regions are country collections, not languages. Country and region filters intersect.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Release / first-air dates").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Menu("Year / Decade") {
                            Button("Any year") { store.filters.setYear(nil) }
                            ForEach((1950...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in Button(String(year)) { store.filters.setYear(year) } }
                            Divider()
                            ForEach([2020, 2010, 2000, 1990, 1980, 1970, 1960], id: \.self) { decade in
                                Button("\(decade)s") { store.filters.fromDate = "\(decade)-01-01"; store.filters.toDate = "\(decade + 9)-12-31" }
                            }
                        }.menuStyle(.borderlessButton)
                    }
                    HStack {
                        TextField("From YYYY-MM-DD", text: $store.filters.fromDate)
                        TextField("To YYYY-MM-DD", text: $store.filters.toDate)
                    }.textFieldStyle(.roundedBorder)
                    Picker("Min. audience rating", selection: $store.filters.minimumRating) {
                        ForEach([0.0, 5, 6, 7, 7.5, 8, 8.5, 9], id: \.self) { value in Text(value == 0 ? "Any" : "\(value.formatted()) / 10").tag(value) }
                    }
                    Picker("Min. votes", selection: $store.filters.minimumVotes) {
                        ForEach([0, 50, 100, 500, 1000, 5000, 10000], id: \.self) { Text($0 == 0 ? "Any" : $0.formatted()).tag($0) }
                    }
                    Picker(store.filters.media == .tv ? "Episode time limit" : "Time limit", selection: $store.filters.maximumRuntime) {
                        ForEach([0, 30, 45, 60, 90, 120, 150, 180], id: \.self) { Text($0 == 0 ? "Any known or unknown" : "Up to \($0) min").tag($0) }
                    }
                }.frame(maxWidth: .infinity)
            }
            Divider().opacity(0.4)
            HStack(spacing: 24) {
                Label("Content & Age Rating", systemImage: "shield.lefthalf.filled").font(.caption.weight(.medium))
                Toggle("Include R-rated movies", isOn: $store.filters.includeRestricted)
                Toggle("Reveal unknown ratings", isOn: $store.filters.includeUnknown)
            }.toggleStyle(.checkbox).font(.caption)
            Text("Minimum age limits results to titles rated at or above the selected threshold (13+, 16+, or 18+). R-rated movies are included by default. Series ratings may vary by episode.")
                .font(.caption2).foregroundStyle(.secondary)
            if store.feed == .releases { Text("Best New Releases uses its selected period instead of the date fields above.").font(.caption2).foregroundStyle(Theme.accent) }
            if let message = store.filters.dateValidationMessage { Text(message).font(.caption).foregroundStyle(Theme.accent) }
        }
    }
}
