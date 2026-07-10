import Foundation
import SwiftData

/// One remembered fact about the user, embedded on-device for retrieval.
/// This is the app's "infinite memory": every meaningful event (workout
/// finished, weight logged, preference stated in chat…) becomes a row, and
/// `MemoryService` retrieves the most relevant ones for any AI question via
/// cosine similarity over `embedding`. Everything stays on device — nothing
/// here syncs or leaves the phone except inside an AI prompt the user
/// explicitly triggers.
@Model
final class MemoryItem {
    @Attribute(.unique) var id: UUID
    var text: String
    /// Broad category ("workout", "nutrition", "body", "preference",
    /// "chat") — lets retrieval and the settings screen group/filter.
    var kind: String
    var createdAt: Date
    /// Sentence embedding from `NLEmbedding` (on-device, free). Empty when
    /// the embedding model was unavailable; such rows fall back to keyword
    /// matching during retrieval.
    var embedding: [Double]

    init(id: UUID = UUID(), text: String, kind: String, createdAt: Date = .now, embedding: [Double] = []) {
        self.id = id
        self.text = text
        self.kind = kind
        self.createdAt = createdAt
        self.embedding = embedding
    }
}

/// Persisted coach-chat transcript so conversations survive relaunches.
/// Local-only by design (health conversations never sync).
@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: String // "user" | "assistant"
    var text: String
    var createdAt: Date

    var isUser: Bool { role == "user" }

    init(id: UUID = UUID(), role: String, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
