import Foundation
import SwiftData

/// Assembles a compact, current snapshot of the user's data for AI prompts:
/// profile, goals, today's intake, 7/30-day trends, and recent training.
/// Deliberately plain text (not JSON) — small models follow it better, and
/// it keeps prompts cheap on the backend-fallback path.
@MainActor
enum AppContextBuilder {

    static func build(context: ModelContext) -> String {
        var lines: [String] = []
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart)!
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: todayStart)!

        // Profile + goals
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let goals = (try? context.fetch(FetchDescriptor<Goals>()))?.first ?? Goals()
        if let profile {
            var bits = ["Name: \(profile.displayName)"]
            if let age = profile.age { bits.append("age \(age)") }
            if profile.heightCM > 0 { bits.append("height \(Int(profile.heightCM))cm") }
            if profile.sex != .unspecified { bits.append(profile.sex.rawValue) }
            bits.append("goal: \(profile.fitnessGoal.label)")
            bits.append("activity: \(profile.activityLevel.label)")
            if !profile.dietRestrictions.isEmpty {
                bits.append("diet: \(profile.dietRestrictions.joined(separator: ", "))")
            }
            lines.append(bits.joined(separator: ", "))
        }
        lines.append("Daily targets: \(goals.calorieTarget) kcal, \(goals.proteinG)g protein, \(goals.carbsG)g carbs, \(goals.fatG)g fat, \(goals.waterML)ml water, \(goals.stepTarget) steps, \(goals.sleepMinutesTarget / 60)h sleep.")
        if let goalKG = goals.weightGoalKG {
            lines.append("Goal weight: \(String(format: "%.1f", goalKG))kg\(goals.goalDate.map { " by \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "").")
        }

        // Weight trend
        let weights = ((try? context.fetch(FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []).filter { $0.deletedAt == nil }
        if let latest = weights.first {
            var line = "Current weight: \(String(format: "%.1f", latest.weightKG))kg (\(latest.date.formatted(date: .abbreviated, time: .omitted)))."
            if let monthOld = weights.first(where: { $0.date <= monthAgo }) {
                let delta = latest.weightKG - monthOld.weightKG
                line += String(format: " 30-day change: %+.1fkg.", delta)
            }
            lines.append(line)
        }

        // Today's nutrition
        let todayLogs = ((try? context.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= todayStart }
        ))) ?? []).filter { $0.deletedAt == nil }
        let kcal = todayLogs.reduce(0.0) { $0 + $1.macroSnapshot.kcal }
        let protein = todayLogs.reduce(0.0) { $0 + $1.macroSnapshot.protein }
        lines.append("Today so far: \(Int(kcal)) kcal eaten, \(Int(protein))g protein, across \(todayLogs.count) logged items.")

        // 7-day nutrition average
        let weekLogs = ((try? context.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= weekAgo && $0.date < todayStart }
        ))) ?? []).filter { $0.deletedAt == nil }
        if !weekLogs.isEmpty {
            let avg = weekLogs.reduce(0.0) { $0 + $1.macroSnapshot.kcal } / 7.0
            lines.append("7-day average intake: \(Int(avg)) kcal/day.")
        }

        // Training (last 30 days)
        let workouts = ((try? context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil && $0.startedAt >= monthAgo },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        ))) ?? []).filter { $0.deletedAt == nil }
        lines.append("Workouts in last 30 days: \(workouts.count).")
        if let last = workouts.first {
            let sets = last.items.flatMap(\.sets).filter(\.isCompleted).count
            let name = last.name.isEmpty ? "Workout" : last.name
            lines.append("Most recent: \(name) on \(last.startedAt.formatted(date: .abbreviated, time: .omitted)), \(sets) sets\(last.caloriesBurned > 0 ? ", ~\(last.caloriesBurned) kcal burned" : "").")
        }

        // Recent PRs
        let prs = ((try? context.fetch(FetchDescriptor<PersonalRecord>(
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        ))) ?? []).filter { $0.deletedAt == nil }.prefix(5)
        if !prs.isEmpty {
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let names = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            let prLines = prs.map { pr in
                "\(names[pr.exerciseID] ?? "exercise") \(pr.kind.rawValue) \(String(format: "%.1f", pr.value))"
            }
            lines.append("Recent PRs: \(prLines.joined(separator: "; ")).")
        }

        // Water + steps today
        let water = ((try? context.fetch(FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= todayStart }
        ))) ?? []).filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.amountML }
        lines.append("Water today: \(water)ml.")
        if let steps = try? context.fetch(FetchDescriptor<StepsCache>(
            predicate: #Predicate { $0.date >= todayStart }
        )).first {
            lines.append("Steps today: \(steps.steps).")
        }

        return lines.joined(separator: "\n")
    }
}
