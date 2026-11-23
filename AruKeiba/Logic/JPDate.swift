import Foundation

/// 日付まわりのユーティリティ（日本時間・月曜始まり）
enum JPDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 2
        return c
    }()

    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    static func startOfDay(_ d: Date) -> Date {
        calendar.startOfDay(for: d)
    }

    static func make(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    static func addDays(_ n: Int, to d: Date) -> Date {
        calendar.date(byAdding: .day, value: n, to: d) ?? d
    }

    /// "2026-11-23" 形式のキー
    static func key(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func key(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func year(_ d: Date) -> Int {
        calendar.component(.year, from: d)
    }

    /// 1=日, 2=月, ... 7=土
    static func weekday(_ d: Date) -> Int {
        calendar.component(.weekday, from: d)
    }

    static func isWeekend(_ d: Date) -> Bool {
        let w = weekday(d)
        return w == 1 || w == 7
    }

    /// その日を含む週の月曜日（0時）
    static func monday(of d: Date) -> Date {
        let s = startOfDay(d)
        let offset = (weekday(s) + 5) % 7 // 月=0, 火=1, ... 日=6
        return addDays(-offset, to: s)
    }

    /// "11/23"
    static func md(_ d: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: d)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }

    /// "月"
    static func weekdaySymbol(_ d: Date) -> String {
        weekdaySymbols[(weekday(d) - 1) % 7]
    }

    /// "11/23(月)"
    static func mdw(_ d: Date) -> String {
        "\(md(d))(\(weekdaySymbol(d)))"
    }

    /// "2026/11/23(月)"
    static func ymdw(_ d: Date) -> String {
        "\(year(d))/\(mdw(d))"
    }
}

extension Int {
    var yen: String { "¥" + self.formatted() }
    var stepsText: String { self.formatted() + "歩" }
}
