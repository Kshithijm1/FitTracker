import Foundation
import NaturalLanguage
import SwiftData

/// On-device long-term memory (the app's RAG store). Facts about the user
/// are embedded with Apple's `NLEmbedding` sentence model — free, offline,
/// private — and retrieved by cosine similarity when the coach needs
/// context. There is no cap on how much it can remember; rows are a few
/// hundred bytes each.
@MainActor
final class MemoryService {
    private let context: ModelContext

    /// Lazily loaded; ~nil on simulators/locales without the asset, in
    /// which case retrieval degrades to keyword overlap scoring.
    private lazy var embedder: NLEmbedding? = NLEmbedding.sentenceEmbedding(for: .english)

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Write

    /// Stores one fact. Deduplicates exact text repeats from the same day
    /// so event hooks (finish workout, log weight) can fire liberally.
    func remember(_ text: String, kind: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let dayStart = Calendar.current.startOfDay(for: .now)
        var dupeCheck = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { $0.text == trimmed && $0.createdAt >= dayStart }
        )
        dupeCheck.fetchLimit = 1
        if let existing = try? context.fetch(dupeCheck), !existing.isEmpty { return }

        let vector = embedder?.vector(for: trimmed.lowercased()) ?? []
        context.insert(MemoryItem(text: trimmed, kind: kind, embedding: vector))
        try? context.save()
    }

    // MARK: - Read

    /// Top-`limit` memories most relevant to `query`, newest-first among
    /// ties. Pure on-device math — safe to call on every chat turn.
    func retrieve(relevantTo query: String, limit: Int = 12) -> [MemoryItem] {
        let all = (try? context.fetch(FetchDescriptor<MemoryItem>())) ?? []
        guard !all.isEmpty else { return [] }

        if let queryVector = embedder?.vector(for: query.lowercased()) {
            let scored = all.map { item -> (MemoryItem, Double) in
                let similarity = Self.cosine(queryVector, item.embedding)
                // Slight recency bias so "last week" beats "two years ago"
                // when similarity ties.
                let ageDays = max(Date.now.timeIntervalSince(item.createdAt) / 86_400, 0)
                return (item, similarity + 0.05 * exp(-ageDays / 90))
            }
            return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
        }

        // Fallback: keyword overlap.
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let scored = all.map { item -> (MemoryItem, Int) in
            let words = Set(item.text.lowercased().split(separator: " ").map(String.init))
            return (item, words.intersection(queryWords).count)
        }
        return scored.sorted {
            $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.createdAt > $1.0.createdAt
        }.prefix(limit).map(\.0)
    }

    var count: Int {
        (try? context.fetchCount(FetchDescriptor<MemoryItem>())) ?? 0
    }

    /// User-facing "forget everything" (Profile → AI & Privacy).
    func eraseAll() {
        try? context.delete(model: MemoryItem.self)
        try? context.save()
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, magA = 0.0, magB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA.squareRoot() * magB.squareRoot())
    }
}
