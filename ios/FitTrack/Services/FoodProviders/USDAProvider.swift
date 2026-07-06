import Foundation

/// USDA FoodData Central: free API key, authoritative for generic/whole
/// foods (PLAN.md §1). Search only — FDC has no reliable single-barcode
/// lookup endpoint, so barcode scanning stays OFF-only
/// (`OpenFoodFactsProvider`).
struct USDAProvider: RemoteFoodProvider {
    private let session: URLSession
    private let apiKey: String
    private let decoder = JSONDecoder()

    /// "DEMO_KEY" works out of the box at a low rate limit (data.gov
    /// convention); register a free key at api.data.gov and set it here
    /// for production traffic.
    init(apiKey: String = "DEMO_KEY", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func search(query: String) async throws -> [FoodItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "20"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(FDCSearchResponse.self, from: data)
        return response.foods.compactMap { $0.toFoodItem() }
    }

    /// Not a supported lookup path for this provider — see type doc.
    func lookup(barcode: String) async throws -> FoodItem? {
        nil
    }
}

private struct FDCSearchResponse: Decodable {
    let foods: [FDCFood]
}

private struct FDCFood: Decodable {
    let description: String
    let brandOwner: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [FDCNutrient]

    func toFoodItem() -> FoodItem? {
        func value(_ names: Set<String>) -> Double {
            foodNutrients.first { names.contains($0.nutrientName) }?.value ?? 0
        }
        let per100g = MacroSet(
            kcal: value(["Energy"]),
            protein: value(["Protein"]),
            carbs: value(["Carbohydrate, by difference"]),
            fat: value(["Total lipid (fat)"])
        )
        var servings: [FoodServing] = []
        if let servingSize, let servingSizeUnit, servingSizeUnit.lowercased() == "g" {
            servings.append(FoodServing(label: "\(Int(servingSize))g serving", grams: servingSize))
        }
        return FoodItem(
            name: description,
            brand: brandOwner,
            source: .usda,
            per100g: per100g,
            servings: servings
        )
    }
}

private struct FDCNutrient: Decodable {
    let nutrientName: String
    let value: Double
}
