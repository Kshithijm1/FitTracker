import Foundation

// MARK: - Shared AI DTOs

struct FoodPhotoCandidate: Decodable, Identifiable, Hashable {
    let name: String
    let estimatedGrams: Double
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    var id: String { name }

    var macroSet: MacroSet { MacroSet(kcal: kcal, protein: protein, carbs: carbs, fat: fat) }
}

struct EquipmentAnalysis: Decodable {
    struct Suggestion: Decodable, Identifiable, Hashable {
        let exerciseName: String
        let reason: String
        var id: String { exerciseName }
    }

    let equipment: String
    /// Weight read off the photo (plate/dumbbell markings), if visible.
    let detectedWeightKG: Double?
    let suggestions: [Suggestion]
}

struct ImportedRecipe: Decodable {
    struct Ingredient: Decodable, Identifiable, Hashable {
        let name: String
        let grams: Double
        let kcalPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        var id: String { name }
    }

    let name: String
    let servings: Int
    let ingredients: [Ingredient]
}

// MARK: - Client

/// Thin wrappers around the backend's `/v1/ai/*` routes (all auth-required;
/// the Anthropic key never touches the device). Kept separate from
/// `AIService` so the routing logic there stays readable.
@MainActor
enum BackendAIClient {

    private struct ChatBody: Encodable {
        let instructions: String
        let prompt: String
    }
    private struct ChatResponse: Decodable { let reply: String }

    static func chat(instructions: String, prompt: String) async throws -> String {
        let response: ChatResponse = try await APIClient.shared.request(
            "POST", "/v1/ai/chat",
            body: ChatBody(instructions: instructions, prompt: prompt),
            authenticated: true
        )
        return response.reply
    }

    private struct PhotoBody: Encodable {
        let imageBase64: String
        let userContext: String?
    }
    private struct FoodPhotoResponse: Decodable { let foods: [FoodPhotoCandidate] }

    static func foodPhoto(jpegData: Data) async throws -> [FoodPhotoCandidate] {
        let response: FoodPhotoResponse = try await APIClient.shared.request(
            "POST", "/v1/ai/food-photo",
            body: PhotoBody(imageBase64: jpegData.base64EncodedString(), userContext: nil),
            authenticated: true
        )
        return response.foods
    }

    static func equipmentPhoto(jpegData: Data, userContext: String) async throws -> EquipmentAnalysis {
        try await APIClient.shared.request(
            "POST", "/v1/ai/equipment-photo",
            body: PhotoBody(imageBase64: jpegData.base64EncodedString(), userContext: userContext),
            authenticated: true
        )
    }

    private struct RecipeBody: Encodable { let source: String }

    static func importRecipe(urlOrText: String) async throws -> ImportedRecipe {
        try await APIClient.shared.request(
            "POST", "/v1/ai/recipe-import",
            body: RecipeBody(source: urlOrText),
            authenticated: true
        )
    }
}
