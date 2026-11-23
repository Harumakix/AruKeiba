import Foundation
import SwiftUI

/// アプリ全体の状態と台帳
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published private(set) var steps: [String: Int] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private let health = HealthKitService()
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("arukeiba.json")
        self.fileURL = url

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: url),
           let decoded = try? decoder.decode(AppData.self, from: raw) {
            self.data = decoded
        } else {
            self.data = AppData(startDateKey: JPDate.key(JPDate.monday(of: Date())))
        }
    }

    // MARK: - 保存

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            errorMessage = "保存に失敗しました：\(error.localizedDescription)"
        }
    }

    // MARK: - 状態

    var startDate: Date {
        JPDate.date(fromKey: data.startDateKey) ?? JPDate.monday(of: Date())
    }

    var startMonday: Date { JPDate.monday(of: startDate) }

    /// 現在の借金残高
    var debt: Int { data.settled.last?.debtAfter ?? 0 }

    /// 次に精算すべき週の月曜
    var nextMondayToSettle: Date {
        if let last = data.settled.last, let d = JPDate.date(fromKey: last.mondayKey) {
            return JPDate.addDays(7, to: d)
        }
        return startMonday
    }

    func settlement(for monday: Date) -> SettledWeek? {
        let k = JPDate.key(monday)
        return data.settled.first { $0.mondayKey == k }
    }

    /// 精算待ちの週（古い順）
    func pendingMondays(today: Date = Date()) -> [Date] {
        let todayStart = JPDate.startOfDay(today)
        var result: [Date] = []
        var m = nextMondayToSettle
        while JPDate.addDays(5, to: m) <= todayStart, result.count < 520 {
            result.append(m)
            m = JPDate.addDays(7, to: m)
        }
        return result
    }

    func summary(for monday: Date, today: Date = Date()) -> WeekSummary {
        let todayStart = JPDate.startOfDay(today)
        let start = JPDate.startOfDay(startDate)
        let exempt = Set(data.exemptDays)
        let days: [DayInfo] = (0..<7).map { i in
            let d = JPDate.addDays(i, to: monday)
            let k = JPDate.key(d)
            return DayInfo(
                date: d,
                key: k,
                steps: steps[k] ?? 0,
                holidayName: JapaneseHolidays.name(for: d),
                isExempt: exempt.contains(k),
                isWeekend: JPDate.isWeekend(d),
                isBeforeStart: d < start,
                isFuture: d > todayStart,
                isToday: d == todayStart
            )
        }
        return WeekSummary(monday: monday, days: days, dailyQuota: data.dailyQuota, today: todayStart)
    }

    // MARK: - ヘルスケア

    func requestAuthorization() async {
        guard health.isAvailable else {
            errorMessage = "この端末ではヘルスケアが使えません"
            return
        }
        do {
            try await health.requestAuthorization()
        } catch {
            errorMessage = "ヘルスケアの許可リクエストに失敗：\(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        guard health.isAvailable else {
            errorMessage = "この端末ではヘルスケアが使えません"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await health.requestAuthorization()
            let now = Date()
            let thisMonday = JPDate.monday(of: now)
            let from = min(nextMondayToSettle, thisMonday)
            let to = JPDate.addDays(7, to: thisMonday)
            steps = try await health.dailySteps(from: from, to: to)
            lastUpdated = now
            hasLoadedOnce = true
            errorMessage = nil
        } catch {
            errorMessage = "歩数の取得に失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - 精算

    /// 週を精算する。repay は超過分のうち借金返済に回す額（残りは競馬資金）
    func settle(_ week: WeekSummary, repay: Int) {
        guard JPDate.key(week.monday) == JPDate.key(nextMondayToSettle) else { return }
        let before = debt
        let diff = week.diff
        let added = max(0, -diff)
        let surplus = max(0, diff)
        let repaid = min(max(0, repay), min(surplus, before))
        let record = SettledWeek(
            mondayKey: JPDate.key(week.monday),
            workdays: week.workdayCount,
            dailyQuota: week.dailyQuota,
            steps: week.steps,
            quota: week.quota,
            diff: diff,
            debtBefore: before,
            addedDebt: added,
            repaid: repaid,
            raceBudget: surplus - repaid,
            debtAfter: before + added - repaid,
            settledAt: Date()
        )
        data.settled.append(record)
        save()
    }

    func undoLastSettlement() {
        guard !data.settled.isEmpty else { return }
        data.settled.removeLast()
        save()
    }

    // MARK: - 設定

    func setDailyQuota(_ value: Int) {
        data.dailyQuota = min(max(value, 100), 50_000)
        save()
    }

    var canChangeStartDate: Bool { data.settled.isEmpty }

    func setStartDate(_ date: Date) {
        guard canChangeStartDate else { return }
        data.startDateKey = JPDate.key(JPDate.startOfDay(date))
        save()
        Task { await refresh() }
    }

    func addExemptDay(_ date: Date) {
        let k = JPDate.key(date)
        guard !data.exemptDays.contains(k) else { return }
        data.exemptDays.append(k)
        data.exemptDays.sort()
        save()
    }

    func removeExemptDays(_ keys: [String]) {
        data.exemptDays.removeAll { keys.contains($0) }
        save()
    }

    func resetAll() {
        data = AppData(
            dailyQuota: data.dailyQuota,
            startDateKey: JPDate.key(JPDate.monday(of: Date()))
        )
        save()
        Task { await refresh() }
    }

    // MARK: - 集計（履歴画面用）

    var totalAddedDebt: Int { data.settled.reduce(0) { $0 + $1.addedDebt } }
    var totalRepaid: Int { data.settled.reduce(0) { $0 + $1.repaid } }
    var totalRaceBudget: Int { data.settled.reduce(0) { $0 + $1.raceBudget } }
    var achievedWeeks: Int { data.settled.filter { $0.diff >= 0 && $0.workdays > 0 }.count }
}
