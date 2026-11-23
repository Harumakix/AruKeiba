import SwiftUI

/// 週の精算シート
struct SettleSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let week: WeekSummary

    @State private var repay: Int = 0

    private var surplus: Int { max(0, week.diff) }
    private var maxRepay: Int { max(0, min(surplus, store.debt)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("対象の週") {
                    LabeledContent("期間", value: week.rangeLabel)
                    LabeledContent("平日日数", value: "\(week.workdayCount)日")
                    LabeledContent("ノルマ", value: week.quota.stepsText)
                    LabeledContent("平日の合計", value: week.steps.stepsText)
                }

                if week.workdayCount > 0 && week.steps == 0 {
                    Section {
                        Label("歩数が0歩になってるよ。ヘルスケアの読み取り許可がオフかも。設定タブを確認してから精算してね",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.debt)
                    }
                }

                if week.diff < 0 {
                    Section("結果：ノルマ未達…") {
                        LabeledContent("不足", value: (-week.diff).stepsText)
                        LabeledContent("借金に加算", value: (-week.diff).yen)
                            .foregroundStyle(Theme.debt)
                        LabeledContent("精算後の借金", value: (store.debt - week.diff).yen)
                    }
                } else if week.workdayCount == 0 {
                    Section("結果") {
                        Text("対象の平日がない週だよ。借金も競馬資金も発生しないよ")
                    }
                } else {
                    Section("結果：ノルマ達成！ +\(surplus.yen)") {
                        if maxRepay > 0 {
                            Stepper(value: $repay, in: 0...maxRepay, step: 100) {
                                LabeledContent("返済に回す", value: repay.yen)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(repay) },
                                    set: { repay = min(max(Int($0.rounded()), 0), maxRepay) }
                                ),
                                in: 0...Double(maxRepay)
                            )
                            HStack {
                                Button("全部競馬に") { repay = 0 }
                                Spacer()
                                Button("返済MAX") { repay = maxRepay }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("借金なし！超過分は全部競馬資金だよ 🏇")
                        }
                        LabeledContent("日曜の競馬資金", value: (surplus - repay).yen)
                            .foregroundStyle(Theme.race)
                            .fontWeight(.bold)
                        LabeledContent("精算後の借金", value: (store.debt - repay).yen)
                    }

                    if week.isRaceDayOver {
                        Section {
                            Text("この週の日曜はもう過ぎてるよ。競馬資金は記録として残るけど、使える期限は切れてるので返済に回すのもアリ")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("週の精算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("精算する") {
                        store.settle(week, repay: repay)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
