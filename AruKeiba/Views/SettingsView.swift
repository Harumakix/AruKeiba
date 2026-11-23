import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newExemptDate = Date()
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Stepper(
                    value: Binding(
                        get: { store.data.dailyQuota },
                        set: { store.setDailyQuota($0) }
                    ),
                    in: 500...30_000,
                    step: 500
                ) {
                    LabeledContent("1日のノルマ", value: store.data.dailyQuota.stepsText)
                }
            } header: {
                Text("ノルマ")
            } footer: {
                Text("変更すると、まだ精算していない週に反映されるよ。精算済みの週はそのまま。")
            }

            Section {
                DatePicker(
                    "集計開始日",
                    selection: Binding(
                        get: { store.startDate },
                        set: { store.setStartDate($0) }
                    ),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .disabled(!store.canChangeStartDate)
            } header: {
                Text("集計開始日")
            } footer: {
                if store.canChangeStartDate {
                    Text("この日より前の平日はノルマ対象外になるよ。")
                } else {
                    Text("精算済みの週があるので変更できないよ（全データをリセットすると変更できる）。")
                }
            }

            Section {
                ForEach(store.data.exemptDays, id: \.self) { key in
                    if let d = JPDate.date(fromKey: key) {
                        Text(JPDate.ymdw(d))
                    } else {
                        Text(key)
                    }
                }
                .onDelete { offsets in
                    let keys = offsets.map { store.data.exemptDays[$0] }
                    store.removeExemptDays(keys)
                }
                DatePicker("日付", selection: $newExemptDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                Button("免除日に追加") {
                    store.addExemptDay(newExemptDate)
                }
            } header: {
                Text("ノルマ免除日")
            } footer: {
                Text("有給や会社の休み（年末年始など）を登録すると、その日はノルマ対象外になるよ。左スワイプで削除。")
            }

            Section {
                NavigationLink("祝日一覧を見る") {
                    HolidayListView()
                }
            } header: {
                Text("祝日")
            } footer: {
                Text("日本の祝日（振替休日・国民の休日を含む）は自動でノルマ対象外になるよ。")
            }

            Section {
                Button("歩数の読み取りを許可する") {
                    Task {
                        await store.requestAuthorization()
                        await store.refresh()
                    }
                }
            } header: {
                Text("ヘルスケア")
            } footer: {
                Text("許可したのに0歩のままのときは、iPhoneの「設定」→「ヘルスケア」→「データアクセスとデバイス」→「AruKeiba」で「歩数」をオンにしてね。")
            }

            Section {
                Button("全データをリセット", role: .destructive) {
                    confirmReset = true
                }
            } footer: {
                Text("精算履歴・借金・免除日がすべて消えて、今週から集計し直しになるよ（ノルマ設定は残る）。")
            }
        }
        .navigationTitle("設定")
        .confirmationDialog("本当にリセットする？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("全データをリセット", role: .destructive) {
                store.resetAll()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("借金も履歴も消えて元に戻せないよ")
        }
    }
}

struct HolidayListView: View {
    @State private var year = JPDate.year(Date())

    private struct Item: Identifiable {
        let key: String
        let name: String
        var id: String { key }
    }

    var body: some View {
        let list: [Item] = JapaneseHolidays.holidays(in: year)
            .map { Item(key: $0.key, name: $0.value) }
            .sorted { $0.key < $1.key }
        List {
            Section {
                Stepper("\(String(year))年", value: $year, in: 2000...2099)
            }
            Section("\(list.count)日") {
                ForEach(list) { item in
                    HStack {
                        if let d = JPDate.date(fromKey: item.key) {
                            Text(JPDate.mdw(d))
                                .monospacedDigit()
                                .frame(width: 84, alignment: .leading)
                        }
                        Text(item.name)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("祝日一覧")
    }
}
