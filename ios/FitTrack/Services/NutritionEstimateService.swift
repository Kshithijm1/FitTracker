import Foundation

enum EstimateConfidence: String, Decodable {
    case low, medium, high
}

struct NutritionEstimateResponse: Decodable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: EstimateConfidence

    var macroSet: MacroSet {
        MacroSet(kcal: calories, protein: protein, carbs: carbs, fat: fat)
    }
}

private struct EstimateRequestBody: Encodable {
    let description: String
}

/// Client for `POST /v1/nutrition/estimate` (PLAN.md §1/§3) — the AI escape
/// hatch for foods not found via barcode/search. Requires sign-in (the
/// route is auth-protected); callers fall back to manual entry on any
/// failure, including "not signed in".
enum NutritionEstimateService {
    static func estimate(description: String) async throws -> NutritionEstimateResponse {
        let body = EstimateRequestBody(description: description)
        return try await APIClient.shared.request(
            "POST", "/v1/nutrition/estimate", body: body, authenticated: true
        )
    }
}
