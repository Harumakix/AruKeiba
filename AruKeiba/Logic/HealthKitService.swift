import Foundation
import HealthKit

/// ヘルスケアから日別の歩数を読む
final class HealthKitService {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 読み取り許可をリクエスト（2回目以降はダイアログは出ない）
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    /// [日付キー: 歩数] を返す。iPhone・Apple Watchの重複はHealthKit側で除外される
    func dailySteps(from start: Date, to end: Date) async throws -> [String: Int] {
        let calendar = JPDate.calendar
        let anchor = calendar.startOfDay(for: start)
        let stepType = self.stepType
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: anchor, end: end, options: .strictStartDate)
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    if let hkError = error as? HKError, hkError.code == .errorNoData {
                        continuation.resume(returning: [:])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var dict: [String: Int] = [:]
                results?.enumerateStatistics(from: anchor, to: end) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dict[JPDate.key(statistics.startDate)] = Int(value.rounded())
                }
                continuation.resume(returning: dict)
            }
            store.execute(query)
        }
    }
}
