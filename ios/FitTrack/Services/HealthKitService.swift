import Foundation
import HealthKit
import SwiftData
import Observation

/// Read-only HealthKit integration for steps + sleep (PLAN.md §3/§5/§7).
/// FitTrack never writes to Health, and HealthKit data never leaves the
/// device except as the user's own manual log entries — this service only
/// mirrors HealthKit values into local `StepsCache`/`SleepEntry` rows.
@MainActor
@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()
    private let context: ModelContext
    private static let requestedDefaultsKey = "fittrack.healthkit.requested"

    /// HealthKit deliberately never reveals per-type *read* grant status, so
    /// this tracks only "the user has been through the request flow at
    /// least once" — not whether they said yes. Good enough to swap the
    /// Profile row from "Connect" to "Refresh".
    private(set) var hasRequestedAccess: Bool

    private static let stepType = HKQuantityType(.stepCount)
    private static let sleepType = HKCategoryType(.sleepAnalysis)

    init(context: ModelContext) {
        self.context = context
        self.hasRequestedAccess = UserDefaults.standard.bool(forKey: Self.requestedDefaultsKey)
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Call after the user accepts the in-app rationale screen — this is
    /// what triggers the system permission prompt.
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: [Self.stepType, Self.sleepType])
        hasRequestedAccess = true
        UserDefaults.standard.set(true, forKey: Self.requestedDefaultsKey)
        await refreshToday()
    }

    /// Pulls today's steps and last night's sleep into local storage.
    /// Safe to call anytime (foreground refresh, pull-to-refresh) — it only
    /// overwrites the device-local, non-synced HealthKit-sourced rows.
    func refreshToday() async {
        guard isHealthDataAvailable else { return }
        async let steps = fetchTodaySteps()
        async let sleepMinutes = fetchLastNightSleepMinutes()
        let (stepCount, minutes) = await (steps, sleepMinutes)

        if let stepCount {
            upsertStepsCache(steps: stepCount)
        }
        if let minutes {
            upsertSleepEntry(minutes: minutes)
        }
    }

    private func fetchTodaySteps() async -> Int? {
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: Self.stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: sum.map(Int.init))
            }
            healthStore.execute(query)
        }
    }

    private func fetchLastNightSleepMinutes() async -> Int? {
        let end = Date.now
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: Self.sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                ]
                let totalSeconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? Int(totalSeconds / 60) : nil)
            }
            healthStore.execute(query)
        }
    }

    private func upsertStepsCache(steps: Int) {
        let today = Calendar.current.startOfDay(for: .now)
        let existing = try? context.fetch(FetchDescriptor<StepsCache>(predicate: #Predicate { $0.date == today })).first
        if let existing {
            existing.steps = steps
            existing.source = .healthkit
        } else {
            context.insert(StepsCache(date: today, steps: steps, source: .healthkit))
        }
        try? context.save()
    }

    private func upsertSleepEntry(minutes: Int) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let existing = try? context.fetch(
            FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.date >= today && $0.date < tomorrow })
        ).first(where: { $0.source == .healthkit })

        if let existing {
            existing.minutes = minutes
            existing.markDirty()
        } else {
            context.insert(SleepEntry(date: today, minutes: minutes, source: .healthkit))
        }
        try? context.save()
    }
}
