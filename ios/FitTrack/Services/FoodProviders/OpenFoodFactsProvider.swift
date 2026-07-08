import Foundation

/// Open Food Facts: free, no API key, best-in-class barcode + branded-food
/// coverage (PLAN.md §1). Primary barcode source; also contributes to
/// text search merge-in.
struct OpenFoodFactsProvider: RemoteFoodProvider {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [FoodItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(OFFSearchResponse.self, from: data)
        return response.products.compactMap { $0.toFoodItem() }
    }

    func lookup(barcode: String) async throws -> FoodItem? {
        // Product barcodes (UPC-A/UPC-E/EAN-8/EAN-13) are digits-only. VisionKit
        // can in principle hand back any scanned payload string depending on
        // symbology, so this is validated (not just trusted) before it's
        // interpolated into a URL — an unvalidated value here previously could
        // crash the app via a force-unwrapped `URL(string:)`.
        guard !barcode.isEmpty, barcode.allSatisfy(\.isNumber) else { return nil }
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }

        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(OFFProductResponse.self, from: data)
        guard response.status == 1, let product = response.product else { return nil }
        return product.toFoodItem(barcode: barcode)
    }
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
    }

    func toFoodItem(barcode: String? = nil) -> FoodItem? {
        guard let productName, !productName.isEmpty, let nutriments else { return nil }
        let per100g = MacroSet(
            kcal: nutriments.energyKcal100g ?? 0,
            protein: nutriments.proteins100g ?? 0,
            carbs: nutriments.carbohydrates100g ?? 0,
            fat: nutriments.fat100g ?? 0
        )
        var servings: [FoodServing] = []
        if let servingSize, let grams = Self.parseGrams(from: servingSize) {
            servings.append(FoodServing(label: servingSize, grams: grams))
        }
        return FoodItem(
            name: productName,
            brand: brands,
            source: .off,
            barcode: barcode ?? code,
            per100g: per100g,
            servings: servings
        )
    }

    private static func parseGrams(from servingSize: String) -> Double? {
        let digits = servingSize.prefix(while: { $0.isNumber || $0 == "." })
        return Double(digits)
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
