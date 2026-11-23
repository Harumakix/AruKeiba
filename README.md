# AruKeiba（あるけいば）🐎👣

平日の歩数ノルマを割ったら借金、超えたら日曜の競馬資金になる、ダイエット用の歩数管理アプリ（iPhone / iOS 17以降）。

## ルール

- ヘルスケアの歩数を日別に読み取る
- ノルマ対象は **平日（月〜金）だけ**。土日・祝日（振替休日・国民の休日込み）・自分で登録した免除日は対象外
- 週のノルマ ＝ 1日のノルマ（初期値 3,000歩・設定で変更可）× その週の対象平日数
- **土曜日になると、その週を精算**できる
  - ノルマ未達 → 足りない歩数 × 1円が **借金** に加算
  - ノルマ達成 → 超えた歩数 × 1円を **返済** と **日曜の競馬資金** に自分で振り分け
  - 競馬資金はその週の日曜で消滅（繰り越しなし）
- 精算は古い週から順番に。間違えたら履歴タブから「最後の精算」を取り消せる

## Windows から iPhone に入れる手順

Mac がなくても、GitHub のクラウド Mac でビルド → Sideloadly で iPhone に転送、で入れられる。

### 1. GitHub でビルドする（初回だけ準備あり）

1. [GitHub](https://github.com) のアカウントを作る（無料）
2. 右上の「＋」→「New repository」→ 名前を `AruKeiba` などにして作成
   - Public でも Private でもOK（Public だとビルド時間が無制限・無料）
3. 作ったリポジトリの画面で「uploading an existing file」をクリックし、
   このフォルダの中身（`.github` フォルダ、`AruKeiba` フォルダ、`project.yml`、`README.md`）を
   **まとめてドラッグ＆ドロップ** →「Commit changes」
   - `.github/workflows/build.yml` がちゃんと入っているか確認してね（これがビルドの設定）
4. 上の「Actions」タブを開くと「Build IPA」が自動で走り出す（5分くらい）
   - 走ってなければ「Build IPA」→「Run workflow」
5. 緑のチェックが付いたら、その実行を開いて下の「Artifacts」から **AruKeiba-ipa** をダウンロード → 解凍すると `AruKeiba.ipa` が出てくる

### 2. iPhone にインストールする（Sideloadly）

1. Windows に **iTunes** と **iCloud** を入れる（Microsoft Store 版ではなく、Apple 公式サイトのWeb版が推奨）
2. [Sideloadly](https://sideloadly.io) をインストールして起動
3. iPhone を USB で PC につなぐ（「このコンピュータを信頼しますか？」→ 信頼）
4. Sideloadly に `AruKeiba.ipa` をドラッグ、Apple ID を入力して「Start」
   - Apple ID は普段のものでOK（無料。開発者登録は不要）。心配ならサブの Apple ID でも可
5. iPhone 側の設定
   - 「設定」→「プライバシーとセキュリティ」→「デベロッパモード」をオン（再起動あり）
   - 「設定」→「一般」→「VPNとデバイス管理」→ 自分の Apple ID を「信頼」
6. アプリを開くとヘルスケアの許可が出るので、「歩数」をオン

### 注意：無料 Apple ID だと 7日ごとに入れ直しが必要

- 7日経つとアプリが起動しなくなるので、同じ手順で Sideloadly からもう一度インストールする（**データは消えない**）
- Sideloadly の「Auto-refresh」を使うと、PC と iPhone が同じ Wi-Fi にいる間に自動で更新してくれる
- 入れ直しが面倒なら、Apple Developer Program（有料・年額）に登録すると1年有効になる

## うまくいかないとき

- **歩数がずっと0**：「設定」→「ヘルスケア」→「データアクセスとデバイス」→「AruKeiba」で「歩数」をオン
- **Sideloadly でバンドルIDのエラー**：`project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を他とかぶらない文字列（例 `jp.自分のニックネーム.arukeiba`、英数字とドットのみ）に変えて、GitHub で再ビルド
- **HealthKit の権限エラーで起動時に落ちる / 許可画面が出ない**：Sideloadly の Advanced Options でエンタイトルメントを外す設定になっていないか確認

## 中身（開発メモ）

- SwiftUI / HealthKit（`HKStatisticsCollectionQuery` で日別合計。iPhone と Apple Watch の重複は HealthKit 側で除外）
- 祝日は端末内で計算（2000〜2099年、振替休日・国民の休日・2019〜2021年の特例込み）
- データは端末内の JSON（Application Support/arukeiba.json）
- Xcode プロジェクトは XcodeGen（`project.yml`）から生成
