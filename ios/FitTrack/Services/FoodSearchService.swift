import Foundation
import SwiftData

/// A remote food-database lookup. Phase 1 ships no concrete conformer —
/// search works local-cache-only, which already covers recents/frequents/
/// custom foods. Phase 3 adds `USDAProvider`/`OpenFoodFactsProvider` and
/// wires them in via `FoodSearchService.remoteProviders`.
protocol RemoteFoodProvider {
    func search(query: String) async throws -> [FoodItem]
    func lookup(barcode: String) async throws -> FoodItem?
}

/// Local-cache-first food search: instant results from previously-seen
/// `FoodItem` rows, then remote providers merged in when available
/// (PLAN.md §3 "type -> local results instantly, remote merge in").
@MainActor
final class FoodSearchService {
    private let context: ModelContext
    var remoteProviders: [RemoteFoodProvider] = []

    init(context: ModelContext) {
        self.context = context
    }

    /// Recents/frequents grid shown when the log sheet opens, before any typing.
    func recentsAndFrequents(limit: Int = 12) throws -> [FoodItem] {
        var descriptor = FetchDescriptor<FoodItem>(
            sortBy: [
                SortDescriptor(\.lastUsedAt, order: .reverse),
                SortDescriptor(\.useCount, order: .reverse),
            ]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Local results first (synchronous, instant); remote results merged in
    /// as they arrive via the returned async sequence-like callback.
    func searchLocal(query: String, limit: Int = 25) throws -> [FoodItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try recentsAndFrequents(limit: limit)
        }
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.localizedStandardContains(query) }
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Fetches remote results and caches them locally so repeat searches
    /// are instant and work offline thereafter (PLAN.md §1 Nutrition data).
    func searchRemote(query: String) async -> [FoodItem] {
        var merged: [FoodItem] = []
        for provider in remoteProviders {
            if let results = try? await provider.search(query: query) {
                merged.append(contentsOf: results)
                results.forEach { context.insert($0) }
            }
        }
        if !merged.isEmpty {
            try? context.save()
        }
        return merged
    }

    func lookupBarcode(_ barcode: String) async throws -> FoodItem? {
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        descriptor.fetchLimit = 1
        if let cached = try context.fetch(descriptor).first {
            return cached
        }
        for provider in remoteProviders {
            if let match = try await provider.lookup(barcode: barcode) {
                context.insert(match)
                try? context.save()
                return match
            }
        }
        return nil
    }
}
