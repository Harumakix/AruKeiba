import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirmUndo = false

    var body: some View {
        List {
            if store.data.settled.isEmpty {
                ContentUnavailableView(
                    "まだ精算した週がないよ",
                    systemImage: "calendar",
                    description: Text("土曜日になると、その週の精算ができるようになるよ")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("これまでの成績") {
                    LabeledContent("達成した週", value: "\(store.achievedWeeks) / \(store.data.settled.count)週")
                    LabeledContent("借金になった合計", value: store.totalAddedDebt.yen)
                    LabeledContent("返済した合計", value: store.totalRepaid.yen)
                    LabeledContent("競馬資金の合計", value: store.totalRaceBudget.yen)
                    LabeledContent("現在の借金", value: store.debt.yen)
                        .fontWeight(.bold)
                        .foregroundStyle(store.debt > 0 ? Theme.debt : Theme.turf)
                }

                Section("週ごとの記録") {
                    ForEach(store.data.settled.reversed()) { s in
                        HistoryRow(settled: s)
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .toolbar {
            if !store.data.settled.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取り消し") { confirmUndo = true }
                }
            }
        }
        .confirmationDialog("最後の精算を取り消す？", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("最後の精算を取り消す", role: .destructive) {
                store.undoLastSettlement()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            if let last = store.data.settled.last {
                Text("\(last.rangeLabel) の精算を取り消して、精算前の状態に戻すよ")
            }
        }
    }
}

struct HistoryRow: View {
    let settled: SettledWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(settled.rangeLabel)
                    .font(.subheadline.bold())
                Spacer()
                if settled.workdays == 0 {
                    Text("お休み週")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if settled.diff >= 0 {
                    Text("+\(settled.diff.yen)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.turf)
                } else {
                    Text("−\((-settled.diff).yen)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.debt)
                }
            }
            Text("平日\(settled.workdays)日・\(settled.steps.stepsText) / \(settled.quota.stepsText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if settled.diff >= 0 && settled.workdays > 0 {
                    Label(settled.raceBudget.yen, systemImage: "flag.checkered")
                        .foregroundStyle(Theme.race)
                    if settled.repaid > 0 {
                        Label("返済 \(settled.repaid.yen)", systemImage: "arrow.uturn.backward")
                    }
                }
                Spacer()
                Text("借金 \(settled.debtAfter.yen)")
                    .foregroundStyle(settled.debtAfter > 0 ? Theme.debt : .secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
