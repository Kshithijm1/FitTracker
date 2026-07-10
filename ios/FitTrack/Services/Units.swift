import Foundation

/// All unit conversion + display formatting in one place. Storage is always
/// metric (kg, ml, meters, cm); these helpers convert at the UI boundary
/// based on the user's `UserProfile` preferences.
enum Units {
    static let lbPerKG = 2.204_622_6
    static let flOzPerML = 0.033_814
    static let miPerKM = 0.621_371

    // MARK: - Weight

    static func displayWeight(_ kg: Double, unit: UnitPreference) -> Double {
        unit == .imperial ? kg * lbPerKG : kg
    }

    static func weightToKG(_ value: Double, unit: UnitPreference) -> Double {
        unit == .imperial ? value / lbPerKG : value
    }

    static func weightLabel(_ unit: UnitPreference) -> String {
        unit == .imperial ? "lb" : "kg"
    }

    static func formatWeight(_ kg: Double, unit: UnitPreference, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", displayWeight(kg, unit: unit), weightLabel(unit))
    }

    // MARK: - Volume

    static func formatVolume(_ ml: Int, unit: VolumeUnit) -> String {
        switch unit {
        case .milliliters: return "\(ml) ml"
        case .fluidOunces: return String(format: "%.0f fl oz", Double(ml) * flOzPerML)
        }
    }

    // MARK: - Distance

    static func displayDistance(_ meters: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? meters / 1000 * miPerKM : meters / 1000
    }

    static func distanceToMeters(_ value: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? value / miPerKM * 1000 : value * 1000
    }

    static func distanceLabel(_ unit: DistanceUnit) -> String {
        unit == .miles ? "mi" : "km"
    }

    static func speedLabel(_ unit: DistanceUnit) -> String {
        unit == .miles ? "mph" : "km/h"
    }

    static func displaySpeed(_ kph: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? kph * miPerKM : kph
    }

    static func speedToKPH(_ value: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? value / miPerKM : value
    }

    // MARK: - Height

    static func formatHeight(_ cm: Double, unit: UnitPreference) -> String {
        guard cm > 0 else { return "--" }
        if unit == .metric { return "\(Int(cm)) cm" }
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.rounded()) % 12
        return "\(feet)′\(inches)″"
    }
}

/// A food portion unit the user can log in. Everything converts to grams
/// internally (macros are stored per-100g). Volume units use a per-food
/// density when known, defaulting to water density (1 g/ml) — the accepted
/// approximation food loggers use when the source database gives none.
enum FoodUnit: String, CaseIterable, Identifiable {
    case grams, kilograms, ounces, pounds
    case milliliters, teaspoons, tablespoons, cups
    case serving

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grams: return "g"
        case .kilograms: return "kg"
        case .ounces: return "oz"
        case .pounds: return "lb"
        case .milliliters: return "ml"
        case .teaspoons: return "tsp"
        case .tablespoons: return "tbsp"
        case .cups: return "cup"
        case .serving: return "serving"
        }
    }

    /// Grams for one of this unit. `servingGrams` supplies the food's own
    /// serving size when the unit is `.serving`.
    func grams(quantity: Double, servingGrams: Double = 100) -> Double {
        switch self {
        case .grams: return quantity
        case .kilograms: return quantity * 1000
        case .ounces: return quantity * 28.349_5
        case .pounds: return quantity * 453.592
        case .milliliters: return quantity          // 1 g/ml default density
        case .teaspoons: return quantity * 4.929
        case .tablespoons: return quantity * 14.787
        case .cups: return quantity * 236.588
        case .serving: return quantity * max(servingGrams, 1)
        }
    }

    /// Sensible starting quantity when the user switches to this unit.
    var defaultQuantity: Double {
        switch self {
        case .grams: return 100
        case .kilograms: return 0.5
        case .ounces: return 3
        case .pounds: return 0.25
        case .milliliters: return 250
        case .teaspoons: return 1
        case .tablespoons: return 1
        case .cups: return 1
        case .serving: return 1
        }
    }
}
