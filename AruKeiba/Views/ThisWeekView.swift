import SwiftUI

struct ThisWeekView: View {
    @EnvironmentObject private var store: AppStore
    @State private var settlingWeek: WeekSummary?

    var body: some View {
        let today = Date()
        let week = store.summary(for: JPDate.monday(of: today), today: today)
        let pending = store.pendingMondays(today: today)

        ScrollView {
            VStack(spacing: 16) {
                if let error = store.errorMessage {
                    ErrorBanner(message: error)
                }

                if let first = pending.first {
                    PendingBanner(
                        week: store.summary(for: first, today: today),
                        remainingCount: pending.count,
                        disabled: store.isLoading || !store.hasLoadedOnce
                    ) {
                        settlingWeek = store.summary(for: first, today: today)
                    }
                }

                WeekProgressCard(week: week)

                if let settled = store.settlement(for: week.monday) {
                    SettledResultCard(settled: settled)
                }

                DebtCard(debt: store.debt)

                DayListCard(week: week)

                if let updated = store.lastUpdated {
                    Text("最終更新 \(updated.formatted(date: .omitted, time: .shortened))・下に引っぱって更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AruKeiba")
        .refreshable { await store.refresh() }
        .overlay {
            if store.isLoading && !store.hasLoadedOnce {
                ProgressView("歩数を読み込み中…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(item: $settlingWeek) { w in
            SettleSheet(week: w)
                .environmentObject(store)
        }
    }
}

// MARK: - 今週の進捗

struct WeekProgressCard: View {
    let week: WeekSummary

    var body: some View {
        Card {
            HStack {
                Text("今週の平日ノルマ")
                    .font(.headline)
                Spacer()
                Text(week.rangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if week.workdayCount == 0 {
                Text("今週は対象の平日なし！ノルマお休み 🎉")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.turf)
            } else {
                Text("平日\(week.workdayCount)日 × \(week.dailyQuota.stepsText) = \(week.quota.stepsText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(week.steps.formatted())
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("/ \(week.quota.stepsText)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: min(Double(week.steps) / Double(max(week.quota, 1)), 1.0))
                    .tint(week.diff >= 0 ? Theme.turf : Theme.race)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.vertical, 4)

                statusView
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if week.diff >= 0 {
            VStack(alignment: .leading, spacing: 4) {
                Text("達成！ +\(week.diff.yen)")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.turf)
                Text("🏇 歩けば歩くほど日曜の馬券代（または返済）が増えるよ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("あと \((-week.diff).stepsText)")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.race)
                if let perDay = week.neededPerDay {
                    Text("残り平日\(week.remainingWorkdays)日 → 1日あたり \(perDay.stepsText)")
                        .font(.subheadline)
                } else {
                    Text("このままだと \((-week.diff).yen) の借金…！")
                        .font(.subheadline)
                        .foregroundStyle(Theme.debt)
                }
            }
        }
    }
}

// MARK: - 精算結果

struct SettledResultCard: View {
    let settled: SettledWeek

    var body: some View {
        Card {
            Label("今週は精算済み", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Theme.turf)
            if settled.diff < 0 {
                Text("\(settled.addedDebt.yen) を借金に加算したよ")
                    .foregroundStyle(Theme.debt)
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("日曜の競馬資金")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settled.raceBudget.yen)
                            .font(.title.bold())
                            .foregroundStyle(Theme.race)
                    }
                    Spacer()
                    if settled.repaid > 0 {
                        VStack(alignment: .trailing) {
                            Text("返済")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(settled.repaid.yen)
                                .font(.title3.bold())
                        }
                    }
                }
                Text("※ 競馬資金は日曜で消滅。使い切ってね 🐎")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 借金

struct DebtCard: View {
    let debt: Int

    var body: some View {
        Card {
            HStack {
                Image(systemName: debt > 0 ? "exclamationmark.triangle.fill" : "face.smiling")
                    .font(.title2)
                    .foregroundStyle(debt > 0 ? Theme.debt : Theme.turf)
                VStack(alignment: .leading) {
                    Text("借金残高")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(debt > 0 ? debt.yen : "借金なし！")
                        .font(.title2.bold())
                        .foregroundStyle(debt > 0 ? Theme.debt : Theme.turf)
                        .monospacedDigit()
                }
                Spacer()
            }
        }
    }
}

// MARK: - 日別

struct DayListCard: View {
    let week: WeekSummary

    var body: some View {
        Card {
            Text("日別の歩数")
                .font(.headline)
            ForEach(week.days) { day in
                DayRow(day: day, dailyQuota: week.dailyQuota)
                if day.id != week.days.last?.id {
                    Divider()
                }
            }
        }
    }
}

struct DayRow: View {
    let day: DayInfo
    let dailyQuota: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(JPDate.mdw(day.date))
                .font(.body.monospacedDigit())
                .fontWeight(day.isToday ? .bold : .regular)
                .frame(width: 84, alignment: .leading)

            if let reason = day.excludedReason {
                Text(reason)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .lineLimit(1)
            } else if day.isToday {
                Text("今日")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.turf, in: Capsule())
            }

            Spacer()

            if day.isFuture {
                Text("—")
                    .foregroundStyle(.secondary)
            } else {
                Text(day.steps.stepsText)
                    .monospacedDigit()
                    .foregroundStyle(day.isWorkday ? .primary : .secondary)
                if day.isWorkday {
                    Image(systemName: day.steps >= dailyQuota ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(day.steps >= dailyQuota ? Theme.turf : .secondary)
                }
            }
        }
        .opacity(day.isWorkday ? 1.0 : 0.6)
    }
}

// MARK: - バナー

struct PendingBanner: View {
    let week: WeekSummary
    let remainingCount: Int
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Card {
            Label(remainingCount > 1 ? "精算待ちの週が\(remainingCount)つあるよ" : "精算できる週があるよ",
                  systemImage: "flag.checkered")
                .font(.headline)
            Text(week.rangeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: action) {
                Text("この週を精算する")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(disabled)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Card {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(Theme.debt)
        }
    }
}
