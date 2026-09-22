# Meta Muse通常1.3のweb_search 400 実装計画

## 1. メタ情報

- status: draft
- 案件名: direct Meta + muse-spark-1.3 のweb_search 400
- 種別: 通常実装
- 計画ファイル: docs/implementation-plan/meta-muse-web-search-content-types.md
- 計画の正本: /Users/iris/Applications/worktree/a822/opencodex
- 計画ブランチ: codex/plan-meta-muse-web-search
- 作成日: 2026/09/21
- 最終更新: 2026/09/22
- Rev: 4
- chat_id: /Users/iris/.codex/sessions/2026/09/22/rollout-2026-09-22T18-12-34-01a0c863-6bc5-7662-8e17-533cad442a74.jsonl
- 引き継ぎ: 親計画のRev.3 commit a584ecf16。分岐元は /Users/iris/Applications/worktree/5bc3/opencodex。このworktreeの既存ファイルを再利用し、親worktreeは変更しない。
- 親計画の固定参照: draft Rev.4（一時凍結）、ブランチ `codex/plan-meta-muse`、commit `692ea74a79d74466e46c346bf36f8af578795ead`。親正本は読み取り専用で参照し、本計画のRev.4とは別の改訂系列として扱う。
- 関連タスク: [認証タイムアウト](codex://threads/01a0c864-baae-7ab0-b1fc-8371d788f18d)、[本タスク](codex://threads/01a0c863-6bc5-7662-8e17-533cad442a74)。親の凍結は本タスクの作業停止・追加許可を意味しない。
- 依頼: 「こちらのスレッドではweb_search 400に対処」「save-docs-plan-modeを使って実装計画」。現段階は計画のみ。

### 承認記録（確定時に記入。記入後は凍結）

- 承認リポジトリ: 未確定
- 承認ブランチ: 未確定
- approved commit SHA: 未確定

## 2. Context

### 実測情報とコード確認の区別

引き継ぎ記録では、2026/09/15 09:08:41、npm版2.51.0、Codex → OpenCodex → `meta-muse/muse-spark-1.3`、adapter `openai-responses`、baseUrl `https://api.meta.ai/v1` で次の400が発生した。通常1.3でありcontributorではない。

```text
tools[].search_content_types is only supported for web_search_preview tools
```

元ログは今回再読しておらず、引き継ぎされた実測情報として扱う。非公開requestId、アカウント情報、鍵は計画・公開資料へ転載しない。v2.55.0は元のソース調査情報であり、実機で再現済みとは扱わない。

### 2026/09/22の読み取り調査

- 現在のworktreeはv2.15.0由来のコードに計画commitだけを加えた状態。この古いコードには対象互換関数がなく、直接実装修正しない。
- [最新公開リリースページ](https://github.com/lidge-jun/opencodex/releases/latest)は確認時点で[v2.60.0](https://github.com/lidge-jun/opencodex/releases/tag/v2.60.0)を表示。
- 既存ローカルタグv2.60.0（`7c625fc9755c9824653ab944190e243091a2c85c`）をgit showで確認。今回fetch・merge・upstreamへのcheckoutはしていない。
- ローカルremote-tracking ref `upstream/dev`（`39143fddf4ae3055f96f9ff02da38c2a67512b9b`）でも対象ソース・既存Museテストはv2.60.0と差分なし。このrefが現在のリモート先端とは断定しない。
- v2.60.0と上記dev refでは、STRICT_MODELSは1.2/1.3のcontributorとcontributor-freeの4IDのみ。通常1.3は対象外で、`search_content_types`が除去されず送信ボディに残る経路をコードで確認した。実API再現・テスト実行は今回行っていない。

| 根拠（v2.60.0基準） | 内容 |
|---|---|
| `src/adapters/openai-responses/web-search.ts:72` | 既存の対象モデル4ID |
| 同ファイル:79 | direct Meta、Zen、Goの3つのResponses送信先 |
| 同ファイル:99以降 | モデル・URLの照合後、plain web_searchだけからsearch_content_typesとindexed_web_accessを除去。toolsとinput内additional_toolsを処理 |
| `src/adapters/openai-responses/passthrough.ts:398` | 実効URL・parsed.modelIdを使い送信リクエスト構築中に適用 |
| `tests/providers/muse-spark-web-search-compat.test.ts` | buildForProvider、META_PROVIDER、META_PATH_PROVIDERなど再利用可能な既存fixture |

`supportsOpenAiWebSearchToolFields:false` が除去するのはexternal_web_accessとsearch_context_sizeであり、設定だけで本件のフィールドは消えない。カタログの検索機能を無効化するのではなく、送信時の互換処理で対応する。

### 関連Issue（前回確認: 2026/09/21 18:03 JST）

親タスクでユーザー指定の通常のghによりopen・closed両方を検索した。今回のdirect Meta＋通常1.3に一致するIssueはその検索範囲では未発見。検索結果は当時の記録であり、投稿直前に再確認する。

- [#2442](https://github.com/lidge-jun/opencodex/issues/2442): 同じsearch_content_typesエラー、Go＋1.2-contributor。COMPLETEDでclosed。
- [#3362](https://github.com/lidge-jun/opencodex/issues/3362): Go＋1.3-contributorのindexed_web_access。#3378へ統合してclosed。
- [#3378](https://github.com/lidge-jun/opencodex/issues/3378): #3405で修正との終了コメント。今回の通常1.3 direct Metaを解決済みとは判断しない。
- [#3191](https://github.com/lidge-jun/opencodex/issues/3191): 当時openだったMuse CLI接続方式の機能要望。本件とは別。
- PR #3964、#3456、#2617の経緯は引き継ぎ参考情報。最新状態・適用範囲は実装前の再調査対象。

## 3. スコープ

### やること

- 最新upstreamを取り込んだ共通基点で本件を再評価し、通常1.3のdirect Meta Responses経路だけを新規に互換処理対象へ加える計画。
- 既存contributor系、他宛先、preview、function等の動作を保つ回帰テスト。
- provider説明、Human Test手順、walkthroughの整備。
- このタスクの実装・レビュー・完了判定を認証タイムアウトから独立させる。

### やらないこと（Non-goals）

- 認証タイムアウト、GUI、OAuth、Keychain、ログインAPI、CLIの認証待機の変更。これらは別タスクの責務。
- 通常1.2とZen/Go通常1.3への新規適用。元案は追加検討可能だが、根拠を補って計画を改訂するまで採用しない。
- 全モデルへの無条件適用、web_search自体の削除、previewへの型変更、検索カタログ設定やmodelWireDefaultsの変更。
- 認証タスクの完了を本件の前提にすること、別作業が完了したと仮定すること。
- 今回の実装・テスト実行・upstream取り込み・プロキシ起動・実API要求・push・Issue投稿・PR作成。

## 4. 決定事項

以下はdraftの設計判断を含む。計画全体の承認はまだない。IDは親計画から継続し、取り消した判断も保持する。

| ID | 決定 | 理由 | 却下した案 |
|---|---|---|---|
| D1 | 計画のみ。draftを維持し、計画承認と実装許可を分ける | 継続する実装禁止指示 | 保存を実装開始と解釈する案 |
| D2 | 本タスクの正本はa822 worktreeの既存計画ファイル | 分岐した作業パスと既存計画再利用 | 親5bc3を編集する案 |
| D3 | 実装前に最新upstreamを取り込み基点SHAを記録して再調査 | 起点が古い | v2.15.0へ直接修正する案 |
| D4 | 実測・引き継ぎ・ソース確認・推定を区別 | 再現報告の正確性 | v2.55.0/2.60.0で実機再現済みとする案 |
| D5 | web_searchと非対象フィールドを保持。宛先・モデル・ツール種別を限定 | 他経路の互換性 | 全Museからの無条件除去 |
| D6 | 却下（D10に置換）: このタスクに認証タイムアウトを含めない | ユーザーがタスクを分割 | 2件を同一実装・完了条件で扱う案 |
| D7 | 外部通信不要のリクエスト構築テストと純粋関数テストで検証 | 本件は送信ボディの変換 | 親計画の認証時計・KeychainテストはD10により対象外 |
| D8 | 計画ファイルだけをgit-safetyでcommit、pushなし | 指定スキル | 一括stage/commit |
| D9 | 親タスクの通常gh利用は当時のIssue検索記録として保持 | 当時の明示指示。現在のAPI/CLI使用は適用中の指示に従う | 検索許可を投稿許可へ拡大する案 |
| D10 | このタスクはweb_search 400専用。独立ブランチ・PRで対処 | 今回の明示指示 | 認証変更を同じPRに含める案 |
| D11 | 新規対象をdirect Meta＋通常1.3に限定する設計案 | 実測報告がこの組合せに限られる | 共有Setへ通常1.2/1.3を足しZen/Goにも広げる案は保留 |
| D12 | 新規対象にも既存の2フィールド除去を再利用する設計案 | 同じplain web_search互換処理を一か所で維持 | 一つずつ別の書換関数を増やす案 |

D12のindexed_web_accessは通常1.3で独立に400実測されたと主張しない。既存Muse処理と揃える設計上の選択である。search_content_typesだけに限定する代案も、計画レビュー時に変更可能。

## 5. 実装方針

### 5-1. 基点と作業の分離

1. 実装の明示指示後、別作業の状態とfork devの更新状況を確認する。本タスクの古い計画ブランチへ無条件にupstream全体をmergeしない。
2. safe-git-operations／git-safetyに従って最新公開リリース、upstream/dev、fork devを確認する。最低限最新公開版を含む共通統合基点を用意し、タグ・SHA・fork差分を記録する。既に取り込み済みなら再実施しない。
3. 最新upstream取り込みの差分と本件の修正を分離する。将来のPRはfork originのdev向け。取り込み方針や権限が未確定ならその操作だけ保留し、dirty状態のpull・stash退避・force操作は行わない。
4. issue-handlerを使い、共通基点から実装ブランチ `codex/meta-muse-web-search-compat` を用意する。計画正本はこの計画ブランチで保持し、承認後は凍結。実装worktreeには承認済み計画を引き継ぐ。
5. 最新コードで同等修正があれば重複実装せず、対象表とテストで解決範囲を確かめて計画を改訂する。別の400が出ても今回の問題と混同しない。

### 5-2. 対象判定と既存処理の再利用

新しい汎用設定やカタログ属性は作らず、`stripMuseSparkUnsupportedWebSearchFields` 内で宛先とモデルの組合せを判定する。

1. bodyがplain object、modelIdが文字列であることを確認し、modelIdは既存同様trim＋小文字化する。
2. 実効responseUrlを既存と同じ方法で解析する。不正URL、username/password、query、hash付きは変換しない。originの正規化と末尾スラッシュ除去は維持する。
3. 正規化した宛先が既存3URLのどれかでなければ変換しない。
4. 既存のcontributor系4IDは全3URLで従来どおり許可する。追加条件として、宛先が `https://api.meta.ai/v1/responses` かつmodelIdが厳密に `muse-spark-1.3` の場合だけ許可する。family/prefix一致は使わない。
5. 既存rewriteToolsによりplain web_searchの2フィールドだけを除去する。toolsとinput内additional_toolsの双方を処理し、元オブジェクトは破壊しない。その他のフィールドや別ツールは保持する。

| モデル | direct Meta | Zen | Go |
|---|---|---|---|
| 通常muse-spark-1.3 | 新規に2フィールド除去 | 現状維持 | 現状維持 |
| 通常muse-spark-1.2 | 現状維持 | 現状維持 | 現状維持 |
| 1.2/1.3 contributor、contributor-free | 既存除去維持 | 既存除去維持 | 既存除去維持 |
| その他モデル | 現状維持 | 現状維持 | 現状維持 |

provider名や認証方式による分岐は追加しない。同じ実効URL・通常1.3・Responses adapterならmeta-muse以外の設定名でも適用される。Chat Completionsやmeta-modelのルーティング設定は変えない。

### 5-3. 変更予定箇所

| パス（v2.60.0基準、取り込み後に再確認） | 内容 |
|---|---|
| `src/adapters/openai-responses/web-search.ts` | 宛先別の通常1.3判定を追加。JSDocに対象条件と報告由来の根拠を記載 |
| `tests/providers/muse-spark-web-search-compat.test.ts` | 既存buildForProviderとMeta/Zen/Go fixtureで送信ボディの回帰を確認。必要な純粋関数の境界テストもここへ追加 |
| `tests/responses/responses-routed-web-search-fields.test.ts` | 既存のOpenAI/xAI等の保持契約を検証。新しい必要性がある場合だけテストを追加 |
| `docs-site/src/content/docs/guides/providers.md` | MetaのResponses web_search互換処理と限定範囲を短く説明 |
| `docs-site/src/content/docs/ja/guides/providers.md`等 | 日本語説明を同期し、他ロケールの既存説明に矛盾がないか確認 |
| `docs/test-manual/meta-muse-web-search-content-types.md` | human-test-authorでオフライン検証・任意の実API確認の手順を作成 |
| `docs/walkthrough/meta-muse-web-search-content-types.md` | 基点、差分、コマンド結果、実機未確認事項を記録 |

`passthrough.ts`の呼出順や公開関数シグネチャは変更不要の見込み。既存のtool-name変換、stream終端修復、OpenAI/xAI変換には触れない。新規依存は不要。

- [ ] 最新upstreamを含む基点と、本件が未修正である根拠を記録する。
- [ ] §6の通常1.3送信ボディの失敗テストを先に追加し、失敗理由を確認する。
- [ ] 宛先別判定を追加し、同じテストが成功することを確認する。
- [ ] 既存範囲・非対象範囲のテスト、全体検証を通す。
- [ ] docs-site、Human Test手順、walkthroughを整備する。
- [ ] 差分と秘密情報不在を確認し、本件だけのローカルcommitを作る。

### 判断メモ（実装者が記入）

- 該当なし。実装は未開始。

## 6. 検証方法

### 自動テスト

HTTP送信をせず、既存adapterのbuildRequestから得られるbodyとURLを検査する。純粋関数テストはURLのquery等が別の層で変化しないよう直接呼ぶ。単なるSetの値検査だけで完了としない。

| ケース | 合否基準 |
|---|---|
| 通常1.3＋Meta、tools／input.additional_tools／両方 | 2フィールドが消え、web_search型・user_location・filters・search_context_size・他オプションが残る |
| 2フィールドの各片方のみ／両方／両方なし | ある対象フィールドだけ消える。対象なしの場合は不要な書換えをしない |
| baseUrlとresponsesPathの分割指定 | `/v1/responses`という同じ実効URLで同じ変換が起こる |
| 通常1.3＋Zen/Go、通常1.2＋全3宛先 | 今回の変更では除去を増やさない |
| contributor系4ID×3宛先 | 既存除去を維持 |
| preview／function／混在配列 | plain web_search以外を保持。対象web_searchだけが変わる |
| 他ホスト・似たドメイン・別path・HTTP・非標準port | 不変。HTTPS既定portや末尾スラッシュは既存URL正規化どおり |
| query／hash／URL内資格情報／不正URL | 元bodyのまま |
| trim・大小文字、未知モデル、将来版に似たID | 既存の正規化を維持。完全一致しないIDは不変 |
| null、非object、非配列tools、不正additional_tools | 例外や入力破壊なし |
| 二度適用、元bodyの再利用 | 冪等、入力不変。除去以外に情報を失わない |
| OpenAI公式・xAI・非対象providerの既存テスト | 既存のweb_search動作を維持 |

将来のコマンド候補（取り込み後の配置・AGENTSに合わせて確定）:

```sh
bun test tests/providers/muse-spark-web-search-compat.test.ts tests/responses/responses-routed-web-search-fields.test.ts tests/responses/openai-responses-passthrough.test.ts
bun run typecheck
bun run test
bun run privacy:scan
```

共有adapter変更のため全体テストを必要とする。docs-siteの変更には同ディレクトリのAGENTSとpackage scriptsに従う検証を追加する。GUI・認証を変更しないため、この修正だけを理由にGUI buildや認証専用テストを追加要求しない。成功したチェックはコード不変なら繰り返さない。

### Human Testと実API確認

1. 手順書で修正前後の送信ボディを合成fixtureで確認できるようにする。版・SHA・結果を記録する。
2. 実Meta確認は別途許可後に行う追加の検証。許可がなければ未実施と明記し、自動テスト成功を実機成功と表現しない。
3. 許可された場合は、分離worktree・未使用loopbackポート・専用state/config/auth・検証用Codexホームを使う。具体的な引数は最新CLI定義で確かめ、通常の認証ストアや稼働プロキシと共有しない。ログインタイムアウトの修正はこの手順に混ぜず、Humanが用意した検証用認証を利用する。
4. 通常1.3でweb_search宣言を含む1ターンを送り、2xxと今回の400非発生を確認する。「Hi」の成功だけでは検索実行まで成功したと扱わない。検索実行そのものを確認する場合は別の明示的な検索要求を使う。
5. 別のHTTPエラーや認証失敗は原因を区別する。実APIが使えない場合、本件の送信ボディ検証はオフラインで完了できる。

### 外部共有（このタスクでは未許可）

将来投稿するならprovider_compatibility.ymlの項目で、通常1.3、direct Meta、2.51.0の引き継ぎ実測と新しいコード確認を区別したIssue下書きを作る。関連Issueと対象差分を記載し、投稿前に重複再確認する。PRはfork dev向けの独立PRとし、テンプレート全節を記入する。公開・push・PR作成は別途許可がある場合のみ行う。

## 7. 承認条件

実装中は 7-1・7-2 に当てはまる場合だけ停止してユーザー承認をもらう。それ以外は確認を取らずに進める。

### 7-1. 標準の停止条件（削除不可・計画に無くても常に適用）

- 復元できない削除（`{PROJECT_ROOT}/.trash/YYYYMMDD-hhmmss/` への mv は削除に含まない）
- 既定ブランチ（main / master）への push、本番環境への push・デプロイ、force push
- 外部への公開・送信、本番環境の変更、課金
- 秘密情報・認証情報・セキュリティ設定に触れる操作
- 決定事項（D-ID）や Non-goals に反する変更、スコープの追加、§3・§4・§7・§8 の変更が必要になった場合
- 完了条件を満たす手段がなく、安全な代替もない
- 承認後に計画ファイルが変更されている（`git diff <approved commit SHA> -- <計画ファイル>` に、承認記録の3行、§5 のチェック・判断メモ、§10 以外の差分がある）
- 安全ガード（`git-safety` など）が拒否した、または必須のガードが見つからない
- 本番実行元（`~/Applications/git/<repository>`）の既定ブランチ（main / master）に計画ファイルを commit することになる

### 7-2. 本計画固有の停止条件

- 実装の明示指示がない。計画保存・計画承認だけで実装を開始しない。
- 最新upstreamの取り込み先・既存差分が不明で、他作業との干渉を解消できない。
- 通常1.2、Zen/Go通常ID、別フィールド、認証やGUIの変更が必要になり、現在の対象範囲を広げる必要がある。
- 稼働プロキシ・通常の認証情報・本番環境を共有しなければ実API検証ができない。
- 認証情報の読み取り・実API送信・外部投稿が未許可。これらが不要なオフライン作業は続けられる。
- git-safety、適用中のGitHub/Giteaランチャーの承認・資格情報ガードが停止する。迂回しない。

### 7-3. 事前承認済みの操作

ここに書いた操作は、確定時のユーザー承認で有効になり、実装中は止まらずに実行する。書かれていない外部への作用（push、PR 作成など）は実行しない。

- 該当なし。今回許可されたのは読み取り調査、計画・TODO/MEMO記録、計画ファイルのみのローカルcommit。

既定ブランチ（main / master）・本番環境への push、force push、外部公開、および 7-1 の各項目は事前承認できない。

## 8. 完了条件

以下は将来の実装完了条件。今回の計画保存とは区別する。

- [ ] 最新upstreamを含む基点タグ・SHA・本件の再確認結果がwalkthroughに記載されている。
- [ ] 通常1.3 direct Metaの回帰テストが変更前に失敗、変更後に成功した証拠がある（取り込み済み修正がある場合は同等テストで解決済みと示す）。
- [ ] §6の対象／非対象表どおり送信ボディが変換され、既存contributorと他providerのテストが成功する。
- [ ] typecheck・全体test・privacy:scan・該当docs検証の成功結果が記録されている。
- [ ] docs-siteの説明と実装範囲が一致し、Human Test手順書とwalkthroughが存在する。
- [ ] Humanが手順書で通常1.3の対象範囲と非対象保持をレビューでき、実API確認の実施／未実施を判別できる。実機未確認を動作確認済みとして報告していない。
- [ ] 実装差分が本件に限定され、認証タイムアウトのコード・GUI・設定変更を含まないことをgit diffで確認できる。
- [ ] §5 の実装手順のチェックがすべて付いている

## 9. 未解決事項

| ID | 現在の扱い | 解決方法 |
|---|---|---|
| U1 | 対象外: 認証の失敗画面・経過時間 | 別タスクで扱う |
| U2 | 設計案具体化: 通常1.2とZen/Go通常IDは新規対象外 | D11の限定案を計画レビューで確認。将来の拡張余地は保持 |
| U3 | 対象外: 認証期限API | 別タスクで扱う |
| U4 | 対象外: CLI認証待機 | 別タスクで扱う |
| U5 | 最新upstream取り込み済み共通基点、他作業の状態 | 実装開始後に確認。取り込み操作は今は行わない |
| U6 | 実API利用・外部投稿の範囲 | 許可なし。オフライン検証を標準とし、実施する段階で具体的手順とともに確認 |
| U7 | 投稿直前のIssue重複・関連PR状態 | 前回検索は2026/09/21。投稿が必要なときに再検索 |
| U8 | 解決: 本タスクはweb_search専用に分離 | ユーザーの今回の指示。親計画・別タスクは変更しない |
| U9 | 計画全体の承認 | D11/D12、§7、§8を含めてユーザーがレビュー。現状draft |

実装前の調査で判明するU5は手順に組み込む。実API・投稿の未許可は、それらを完了条件に含めない本計画のオフライン修正を妨げない。

## 10. 改訂履歴

- Rev.1 2026/09/21 — 引き継ぎweb_search案を初めてファイル保存。認証タイムアウトの調査・設計候補・テストを追加し、最新upstream取り込みを将来実装の前提に明記。／理由: ユーザーの追加要望とworktree内docsへの保存指定。v2.60.0をローカルタグから読み取り確認し、旧計画のパス・実測範囲を整理。statusはdraftのまま。
- Rev.2 2026/09/21 — §2にupstream Issue検索結果と先行Issueの相違・終了理由を追加、D9を追加、U7を更新。／理由: ユーザー指示「ghコマンドでupstreamにこの件のISSUEが存在するか確認」「gh-aiは使わない」。一致するIssueは検索範囲では未発見。外部投稿・実装は行わずdraftを維持。
- Rev.3 2026/09/22 — §5-1に2ブランチ・2PRへ分ける推奨案、比較理由、共通基点と統合後の検証を追記し、U8を追加。／理由: ユーザーから分割対応と一括対応の比較を求められたため。採用未確定の提案として記録し、実装用ブランチは作成せずdraftを維持。
- Rev.4 2026/09/22 — a822 worktreeの既存計画をweb_search専用に改訂。D2/D7を更新、D6を却下しD10へ置換、D11/D12を追加。認証実装・GUI検証を対象外にし、direct Meta通常1.3への限定案、宛先別の対象表、回帰テスト、最新upstream取り込み前提を具体化。／理由: ユーザー指示「こちらのスレッドではweb_search 400に対処」「save-docs-plan-modeを使って実装計画」。承認・実装は行わずdraftを維持。
