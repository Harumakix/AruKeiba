import Foundation

/// 1日分の情報
struct DayInfo: Identifiable {
    let date: Date
    let key: String
    let steps: Int
    let holidayName: String?
    let isExempt: Bool
    let isWeekend: Bool
    let isBeforeStart: Bool
    let isFuture: Bool
    let isToday: Bool

    var id: String { key }

    /// ノルマ対象の平日か
    var isWorkday: Bool {
        !isWeekend && holidayName == nil && !isExempt && !isBeforeStart
    }

    /// 対象外の理由（表示用）
    var excludedReason: String? {
        if isBeforeStart { return "集計開始前" }
        if let holidayName { return holidayName }
        if isWeekend { return "土日" }
        if isExempt { return "免除日" }
        return nil
    }
}

/// 1週間（月〜日）の集計
struct WeekSummary: Identifiable {
    let monday: Date
    let days: [DayInfo]
    let dailyQuota: Int
    let today: Date

    var id: String { JPDate.key(monday) }
    var saturday: Date { JPDate.addDays(5, to: monday) }
    var sunday: Date { JPDate.addDays(6, to: monday) }

    var workdays: [DayInfo] { days.filter(\.isWorkday) }
    var workdayCount: Int { workdays.count }
    var steps: Int { workdays.reduce(0) { $0 + $1.steps } }
    var quota: Int { workdayCount * dailyQuota }
    /// プラスなら超過、マイナスなら不足（1歩 = 1円）
    var diff: Int { steps - quota }

    /// 今日を含む、まだ残っている平日の数
    var remainingWorkdays: Int {
        workdays.filter { $0.date >= today }.count
    }

    /// 残り平日で1日あたり何歩必要か
    var neededPerDay: Int? {
        guard diff < 0, remainingWorkdays > 0 else { return nil }
        let short = -diff
        return (short + remainingWorkdays - 1) / remainingWorkdays
    }

    /// 土曜になったら精算できる
    var isSettleable: Bool { today >= saturday }

    /// 日曜が終わったか（競馬資金の期限切れ判定）
    var isRaceDayOver: Bool { today > sunday }

    var rangeLabel: String {
        "\(JPDate.mdw(monday))〜\(JPDate.mdw(sunday))"
    }
}

/// 精算済みの週（その時点の値をスナップショットで保存）
struct SettledWeek: Codable, Identifiable, Equatable {
    let mondayKey: String
    let workdays: Int
    let dailyQuota: Int
    let steps: Int
    let quota: Int
    let diff: Int
    let debtBefore: Int
    let addedDebt: Int
    let repaid: Int
    let raceBudget: Int
    let debtAfter: Int
    let settledAt: Date

    var id: String { mondayKey }

    var monday: Date { JPDate.date(fromKey: mondayKey) ?? Date() }

    var rangeLabel: String {
        let m = monday
        return "\(JPDate.mdw(m))〜\(JPDate.mdw(JPDate.addDays(6, to: m)))"
    }
}

/// 保存データ全体
struct AppData: Codable {
    var dailyQuota: Int
    var startDateKey: String
    var exemptDays: [String]
    var settled: [SettledWeek]

    init(dailyQuota: Int = 3000, startDateKey: String, exemptDays: [String] = [], settled: [SettledWeek] = []) {
        self.dailyQuota = dailyQuota
        self.startDateKey = startDateKey
        self.exemptDays = exemptDays
        self.settled = settled
    }

    enum CodingKeys: String, CodingKey {
        case dailyQuota, startDateKey, exemptDays, settled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyQuota = try c.decodeIfPresent(Int.self, forKey: .dailyQuota) ?? 3000
        startDateKey = try c.decodeIfPresent(String.self, forKey: .startDateKey)
            ?? JPDate.key(JPDate.monday(of: Date()))
        exemptDays = try c.decodeIfPresent([String].self, forKey: .exemptDays) ?? []
        settled = try c.decodeIfPresent([SettledWeek].self, forKey: .settled) ?? []
    }
}
