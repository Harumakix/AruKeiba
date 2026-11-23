import Foundation

/// 日本の祝日計算（2000〜2099年対応）
/// - 国民の祝日に関する法律に基づく固定日・ハッピーマンデー・春分/秋分の日
/// - 振替休日（祝日が日曜なら、次の祝日でない日が休み）
/// - 国民の休日（祝日に挟まれた平日は休み）
/// - 2019〜2021年の特例（即位関連・東京五輪による移動）
enum JapaneseHolidays {
    private static var cache: [Int: [String: String]] = [:]
    private static let lock = NSLock()

    /// その日が祝日なら名前を返す
    static func name(for date: Date) -> String? {
        holidays(in: JPDate.year(date))[JPDate.key(date)]
    }

    /// その年の祝日一覧（キー: "yyyy-MM-dd", 値: 祝日名）
    static func holidays(in year: Int) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[year] { return cached }
        let computed = compute(year)
        cache[year] = computed
        return computed
    }

    private static func compute(_ y: Int) -> [String: String] {
        var h: [String: String] = [:]

        func add(_ m: Int, _ d: Int, _ name: String) {
            h[JPDate.key(y, m, d)] = name
        }

        /// m月の第n月曜日の「日」
        func nthMonday(_ m: Int, _ n: Int) -> Int {
            let wd = JPDate.weekday(JPDate.make(y, m, 1)) // 1=日
            let firstMonday = 1 + (9 - wd) % 7
            return firstMonday + 7 * (n - 1)
        }

        // 春分・秋分の日（1980〜2099年の近似式）
        let base = Double(y - 1980)
        let leapAdj = (y - 1980) / 4
        let shunbun = Int(20.8431 + 0.242194 * base) - leapAdj
        let shubun = Int(23.2488 + 0.242194 * base) - leapAdj

        add(1, 1, "元日")
        add(1, nthMonday(1, 2), "成人の日")
        add(2, 11, "建国記念の日")
        if y >= 2020 {
            add(2, 23, "天皇誕生日")
        } else if y <= 2018 {
            add(12, 23, "天皇誕生日")
        }
        add(3, shunbun, "春分の日")
        add(4, 29, y >= 2007 ? "昭和の日" : "みどりの日")
        add(5, 3, "憲法記念日")
        if y >= 2007 { add(5, 4, "みどりの日") }
        add(5, 5, "こどもの日")

        switch y {
        case 2020: add(7, 23, "海の日")
        case 2021: add(7, 22, "海の日")
        default: add(7, y >= 2003 ? nthMonday(7, 3) : 20, "海の日")
        }

        switch y {
        case 2020: add(8, 10, "山の日")
        case 2021: add(8, 8, "山の日")
        default: if y >= 2016 { add(8, 11, "山の日") }
        }

        add(9, y >= 2003 ? nthMonday(9, 3) : 15, "敬老の日")
        add(9, shubun, "秋分の日")

        switch y {
        case 2020: add(7, 24, "スポーツの日")
        case 2021: add(7, 23, "スポーツの日")
        default: add(10, nthMonday(10, 2), y >= 2020 ? "スポーツの日" : "体育の日")
        }

        add(11, 3, "文化の日")
        add(11, 23, "勤労感謝の日")

        if y == 2019 {
            add(5, 1, "天皇の即位の日")
            add(10, 22, "即位礼正殿の儀の行われる日")
        }

        let original = h

        // 振替休日
        for key in original.keys.sorted() {
            guard let d = JPDate.date(fromKey: key), JPDate.weekday(d) == 1 else { continue }
            var next = JPDate.addDays(1, to: d)
            while h[JPDate.key(next)] != nil {
                next = JPDate.addDays(1, to: next)
            }
            if JPDate.year(next) == y {
                h[JPDate.key(next)] = "振替休日"
            }
        }

        // 国民の休日（祝日に挟まれた日）
        var d = JPDate.make(y, 1, 2)
        let end = JPDate.make(y, 12, 30)
        while d <= end {
            let k = JPDate.key(d)
            if h[k] == nil,
               JPDate.weekday(d) != 1,
               original[JPDate.key(JPDate.addDays(-1, to: d))] != nil,
               original[JPDate.key(JPDate.addDays(1, to: d))] != nil {
                h[k] = "国民の休日"
            }
            d = JPDate.addDays(1, to: d)
        }

        return h
    }
}
