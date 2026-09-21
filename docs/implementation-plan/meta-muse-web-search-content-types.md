# Meta Museのweb_search互換性・プロバイダー追加時の認証待機 実装計画

## 1. メタ情報

- status: draft
- 案件名: Meta Museのweb_search 400と認証完了前のタイムアウト
- 種別: 通常実装
- 計画ファイル: docs/implementation-plan/meta-muse-web-search-content-types.md
- 計画の正本: /Users/iris/Applications/worktree/5bc3/opencodex
- 作成日: 2026/09/21
- 最終更新: 2026/09/21
- Rev: 2
- chat_id: /Users/iris/.codex/sessions/2026/09/21/rollout-2026-09-21T17-43-48-01a0c322-b9b6-7f11-95c1-1978384c3f31.jsonl
- 保存先確認: 2026/09/21、ユーザーがこのworktreeのdocs配下を指定。
- 関連: 引き継ぎ元タスク 01a0c321-244e-7733-b98b-27a488c991ee、[upstream v2.60.0](https://github.com/lidge-jun/opencodex/releases/tag/v2.60.0)
- 作業範囲: 今回は調査・計画保存のみ。計画承認は実装許可ではない。

### 承認記録（確定時に記入。記入後は凍結）

- 承認リポジトリ: 未確定
- 承認ブランチ: 未確定
- approved commit SHA: 未確定

## 2. Context

### 課題A: 通常Muse Spark 1.3のweb_searchが400になる

引き継ぎ情報では、2026/09/15 09:08:41、npm版2.51.0でCodex → OpenCodex → direct Metaの `meta-muse/muse-spark-1.3` が `tools[].search_content_types is only supported for web_search_preview tools` で400となった。adapterは `openai-responses`、baseUrlは `https://api.meta.ai/v1`。通常1.3でありcontributorではない。元ログは今回再読しておらず、これは引き継ぎされた実測記録として扱う。非公開requestId・アカウント・鍵は本文や外部投稿に転載しない。

引き継ぎのv2.55.0・当時のmainはソース調査の根拠であり、v2.55.0で実機400を再現したとは扱わない。PR #3964がcloseされた経緯、関連 #3456・#2617、重複open Issueの有無も元調査時点の情報であり、今回最新状態を再確認していない。

### 課題B: Museの認証が完了する前に追加画面がタイムアウトする

2026/09/21にユーザーが、OpenCodexのプロバイダー機能からMeta AIのMuseを追加すると待ち時間が短く、Muse側の認証終了前にタイムアウトする、と報告。操作画面の詳細、実際の経過時間、エラー文、稼働版は確認待ち。原因を1つに断定せず、以下の異なる期限を区別する。

### 今回確認したコードとバージョン

調査日時: 2026/09/21 17:53 JST付近。

- 作業ツリーの起点はv2.15.0、`1a937d834def5f025188c3046dbcd7a31f45a42a`。この古いツリーに実装修正は行わない。
- GitHubの最新公開リリースはv2.60.0。ローカルに既存の同タグ `7c625fc9755c9824653ab944190e243091a2c85c` があり、`git show`／`git grep`で読み取り調査した。fetch・merge・checkoutによる取り込みはしていない。
- 以下のパスと行番号はすべてv2.60.0のもの。現在の作業ツリーの行番号ではない。
- Rev.1時点の `gh-ai` 調査は専用アカウントのKeychain資格情報取得失敗で停止。その後ユーザーが通常の `gh` 使用・`gh-ai` 不使用を明示したため、Rev.2で通常の `gh` による読み取り検索を実施した。アカウント切替や資格情報変更は行っていない。

| 確認対象 | v2.60.0の確認結果 | 根拠パス・行 |
|---|---|---|
| web_search互換処理 | 通常1.2/1.3を含まず、contributor／contributor-freeの4モデルのみ対象 | `src/adapters/openai-responses/web-search.ts:72` |
| 対象送信先 | direct Meta、Zen、Goの3つのResponses URL | 同ファイル:79 |
| フィールド除去 | 対象モデルかつ対象URLのplain web_searchから2フィールドを除去。toolsとinput内additional_toolsに適用 | 同ファイル:99以降 |
| 既存テスト | v2.60.0では `tests/providers/muse-spark-web-search-compat.test.ts` に移動済み | 当該ファイル。古い「16件」を固定の件数として使わない |
| 追加モーダル | 2秒待機×100回のポーリング後にサーバーのログインをキャンセル | `gui/src/components/use-add-provider-oauth.ts:7,122,140` |
| プロバイダー画面のログイン／追加アカウント／再認証 | 2秒待機×150回の後にキャンセル | `gui/src/pages/use-providers-oauth.ts:129,204` |
| Museデバイス認証 | expires_inから期限を作り、無効値は15分、最大30分。単一HTTP要求は20秒 | `src/oauth/meta-muse-device.ts:38–41,218` |
| 期限のGUI伝達 | onAuth、startLoginFlow、loginレスポンスはURL・説明・コードを返すが、認証期限を返さない | `src/oauth/types.ts:105`、`src/oauth/index.ts:1829`、`src/server/management/oauth-account-routes.ts:215` |
| Keychain取り込み | ローカル取込のKeychain読み取りは5秒、キー検証通信は10秒 | `src/oauth/meta-muse.ts:35–36` |
| CLI側の別経路 | account-authにも2秒×100回の待機。GUIと違い末尾は例外を投げる | `src/cli/account-auth.ts:216`付近 |

200秒／300秒はsleep部分の合計であり、通信時間を含む厳密な壁時計上限ではない。GUIの単一status fetchにもこのループ独自の期限指定はない。Metaが返す実際のexpires_inは今回測っていないため、常に15分とは言わない。

**原因候補:** デバイスコードがまだ有効でも、GUIが先に待機を打ち切り `cancelServerLogin` → `cancelLoginFlow` → AbortControllerで認証を中断する。コード上の不整合は確認済みで、ユーザーの実際の失敗との因果は未実測。数秒で失敗する場合はKeychainの5秒、検証10秒、デバイス要求20秒等を別に切り分ける。

参考ソース: [認証追加画面](https://github.com/lidge-jun/opencodex/blob/v2.60.0/gui/src/components/use-add-provider-oauth.ts)、[Museデバイス認証](https://github.com/lidge-jun/opencodex/blob/v2.60.0/src/oauth/meta-muse-device.ts)、[web_search互換処理](https://github.com/lidge-jun/opencodex/blob/v2.60.0/src/adapters/openai-responses/web-search.ts)。リンク先に対応するローカルタグのソースで内容を確認した。

### upstream Issueの重複確認（2026/09/21 18:03 JST）

ユーザー指定の通常の `gh issue list --repo lidge-jun/opencodex --state all --search ... --limit 100` でopen・closed両方を検索し、関連候補は `gh issue view` で本文・コメント・終了理由を確認した。検索語は `muse`、`search_content_types`、`"meta" "timeout"`、`"oauth" "timeout"`、`"login" "timed out"`、`"login" "timeout"`、`"meta-muse" "login"`。各結果は100件未満で、上限による打ち切りはない。

| Issue | 確認時の状態 | 今回の2件との関係 |
|---|---|---|
| [#2442](https://github.com/lidge-jun/opencodex/issues/2442) OpenCode Go Responses rejects search_content_types on web_search | CLOSED / COMPLETED | 同一エラーの先行報告。ただしOpenCode Go＋1.2-contributor。devで修正済みとしてclose。今回のdirect Meta＋通常1.3とは条件が異なる |
| [#3362](https://github.com/lidge-jun/opencodex/issues/3362) OpenCode Go Muse Spark 1.3 rejects indexed_web_access | CLOSED / NOT_PLANNED | Go＋1.3-contributorの別フィールド拒否。問題否定ではなく#3378へ統合してclose |
| [#3378](https://github.com/lidge-jun/opencodex/issues/3378) OpenCode Go wire contract | CLOSED / COMPLETED | #3405、commit 20011a1c482c1e4051c2ec1c52d0ee9ca9164d6cで修正との終了コメント。今回の通常1.3 direct Metaを解決済みとは判断しない |
| [#3191](https://github.com/lidge-jun/opencodex/issues/3191) Muse Code subscription routing through a process-backed MSP adapter | OPEN | Muse CLI経由の新しい接続方式の機能要望。今回のHTTP web_search互換性・GUI認証期限の不具合とは別件 |

**検索範囲の結論:** direct Meta＋通常 `muse-spark-1.3` の今回の400と、Muse追加画面の200秒／300秒打ち切りに一致するIssueは見つからなかった。同種のweb_search不具合の過去Issueは存在するが、一致するopen Issueを確認できたわけではない。表記差・検索索引の遅延等を含むため「存在しない」と断定しない。投稿する場合は直前に再検索する。今回Issue作成・コメント・再openは行っていない。

## 3. スコープ

### やること

- 2件を一つの計画で管理し、独立したテスト・合否を持たせる。
- 実装開始を別途指示された後、進行中の別作業の状態を確認してから、最新upstreamを安全に取り込む。調査時点の候補はv2.60.0。実装開始時に最新を再確認する。
- 最新コードで両問題が既に直っている場合は重複実装せず、根拠と更新後の検証結果を示す。
- web_searchの除去範囲、認証待機期限、キャンセル、再試行、既存プロバイダーへの影響を設計・検証する。
- 将来の実装では関連docs-site、Human Test手順、walkthroughを更新する。

### やらないこと（Non-goals）

- 今回のコード・設定・テスト実装、テスト実行、プロキシ起動、実API再現要求、upstream取り込み、push、Issue投稿、PR作成。
- 現在進行中の別作業が完了したとの仮定、稼働中プロキシの停止・再起動、既定の認証情報やCodex設定の書き換え。
- 全プロバイダーの待ち時間の一律延長、無期限ポーリング、Metaの認証有効期限の延長。
- 通常1.2やZen/Go通常モデルを、根拠なしに通常1.3 direct Metaと同じ仕様と決めること。
- Keychainのアクセス制御変更、認証・CSRF・同意画面の省略、秘密値の記録。

## 4. 決定事項

| ID | 決定 | 理由 | 却下した案 |
|---|---|---|---|
| D1 | このタスクは計画のみ。draftを維持し、計画承認と実装許可を分ける | ユーザーの実装禁止指示 | 計画保存を実装開始と解釈する案 |
| D2 | 正本を指定worktreeのdocs/implementation-plan配下に保存する | ユーザーの保存先指定 | 本番チェックアウトへの保存 |
| D3 | 将来の実装前に最新upstreamを取り込み、基点SHAを記録して再調査する | 2.15.0と2.60.0では対象ファイルの構造も異なる | 古いworktreeへ直ちに修正する案 |
| D4 | 実測・ユーザー報告・ソース確認・推定を区別する | 誤った再現報告を防ぐ | v2.55.0やv2.60.0でも400実測済みと書く案 |
| D5 | web_search自体と非対象フィールドを保持し、送信先・モデル・ツール種別の限定を維持する | 既存互換性への影響を限定 | 全Muse・全送信先から無条件削除する案 |
| D6 | 認証タイムアウトを追加の修正対象とし、人の認証待ちと単一通信の期限を分けて設計する | 今回の追加要望 | HTTP全体のtimeoutだけを一律に延ばす案 |
| D7 | テストは時計・fetch・Keychainをモックし、期限境界とキャンセル競合を確認する | 長時間実待機と外部認証を自動テストから除く | 実Meta認証だけで自動検証する案 |
| D8 | 計画ファイルだけをgit-safetyでcommitし、pushしない | 指定スキル。TODO・MEMOは別の作業記録 | git add -Aによる一括commit |
| D9 | 今回のupstream Issue検索は通常のghを使用し、gh-aiを使用しない | ユーザーの明示指示 | gh-aiの再試行。外部投稿の許可は含まない |

具体的なモデル追加範囲、期限APIの形式、余裕時間の値は決定しておらず、§5の候補と§9で管理する。

## 5. 実装方針

以下は将来の実装候補であり、実装済みではない。

### 5-1. 基点の更新

1. 別作業の進行状態と既存差分を確認する。完了を勝手に仮定しない。
2. 実装許可後、safe-git-operations／git-safetyに従いupstreamの最新公開版とdevを確認する。v2.60.0固定ではなく開始時点の最新リリース・SHAを記録する。
3. forkへの取り込み方法を既存ブランチ・差分に合わせて決める。mainへの直pushを行わず、将来のPR先はforkのdev。取り込みと実装修正はレビュー上識別できるようにする。
4. issue-handlerを使う実装用分離worktreeで再調査する。ブランチ候補は `codex/meta-muse-web-search-auth-timeout`。計画正本にupstreamを混在させない。
5. upstreamに同等修正がある場合、適用範囲をテストで確かめ、不要な修正を計画から改訂する。

### 5-2. web_search互換性

- 元の最小案はSTRICT_MODELSへ通常1.3と1.2を追加するもの。ただし共有Setの追加はZen/Goにも適用されるため、採用は未確定。
- 比較案は「通常1.3はdirect Metaだけに限定する宛先別モデル対応」。これなら通常1.2とZen/Go通常IDの未確認仕様に変更を広げない。
- いずれも `search_content_types`／`indexed_web_access` だけを削除し、web_search、user_location、filters等を保持する。preview／functionは不変。
- URLの現在の照合仕様（URL解析・末尾スラッシュ正規化・資格情報/query/hashの除外）を保持する。
- `supportsOpenAiWebSearchToolFields:false` の除去対象はexternal_web_access／search_context_sizeであり、本件2フィールドを除去する設定代替にはならない。
- JSDocには通常1.3 direct Metaの2026/09/15の報告と確認範囲を記載し、実機未確認バージョンの再現済み主張をしない。

### 5-3. 認証待機の整合（推奨候補・未確定）

**サーバーが持つ認証の状態・期限をGUIが参照する方式を候補とする。** GUIの100回／150回の独立上限だけで、有効なMuse認証を取り消さない。

- Museで計算済みの期限を、OAuthControllerのonAuth → フロー状態 → `/api/oauth/login`／`status`へ任意メタデータとして伝える。候補は `phase`、`expiresAt`、`remainingMs`。名称と型は最新契約・既存型を確認して確定する。トークン・内部device_codeは返さない。
- 追加画面と既存プロバイダー画面で共通の待機判定を使う。Muse以外は期限メタデータ未提供でも既存フローが動くよう互換性を維持する。
- device承認待ち、承認後のkey取得・保存、手動入力待ちを分ける。deviceコードの期限切れを、承認後の処理を中断する理由に使わない。既存コードの「期限付近でMetaが成功応答したら受け入れる」動作を保持する。
- サーバーが期限を管理し、status取得成功のたびにローカル待機の総期限を延ばすことはしない。相対残り時間と単調時計等でGUIとサーバーの時計差・背景タブ休止に対応する。
- 単一status要求のハングには有限の通信期限を設ける候補を比較する。一時的な通信失敗と認証失効を区別し、通信復帰時に最終状態を確認する。通信断が続く場合の終了条件・猶予値は§9で確定する。
- 拒否・取消・期限切れ・通信失敗を区別して表示し、待機中にキャンセルを使える状態を保つ。手動キャンセル、画面破棄、プロバイダー切替、再試行時の既存世代チェック・キャンセルバリアを維持する。
- device flowから手動キー入力へ移る場合は、既に返した最初のURLだけでは状態更新できないためstatusでのphase更新と期限の扱いを定義する。無期限化はしない。
- ローカルKeychainの5秒は別の失敗経路。ユーザー報告がこの経路なら、人がダイアログへ応答する待機とプロセス停止を別途設計する。既存の「読めない資格情報がある場合に黙って別ログインへ移らない」方針を維持する。現段階では一律延長しない。
- CLI `account-auth` にも200秒相当の待機がある。共通API変更の互換性は検証し、CLI自体の改善を今回含めるかは未決事項とする。

簡易比較案はMuseのGUI待機上限のみ延ばすもの。ただしMetaが返す短い期限・承認後処理・両画面の差を十分表せず、期限を重複管理するため第一候補としない。

### 5-4. 変更候補の所在

| パス（v2.60.0基準） | 変更候補 |
|---|---|
| `src/adapters/openai-responses/web-search.ts` | 通常モデルの適用範囲、既存除去関数の再利用 |
| `tests/providers/muse-spark-web-search-compat.test.ts` | 通常IDと送信先の回帰テスト |
| `src/oauth/meta-muse-device.ts`、`src/oauth/types.ts` | 計算済みの認証期限・phaseを任意メタデータとして通知 |
| `src/oauth/index.ts`、`src/oauth/login-flow-state.ts` | 期限・phaseの保持とstatus投影、既存所有権判定の維持 |
| `src/server/management/oauth-account-routes.ts` | login/statusの追加メタデータ伝達 |
| `gui/src/components/use-add-provider-oauth.ts`、`gui/src/pages/use-providers-oauth.ts` | 共通待機判定、取消と終端状態の扱い |
| `gui/src/pages/providers-shared.ts`、必要な表示部・i18n | 任意型の追加、待機・失効・再試行表示 |
| `tests/providers/meta-muse-device.test.ts`、`meta-muse-login-order.test.ts`、`meta-muse-oauth.test.ts` | provider期限・取込順・キャンセルの維持 |
| `tests/oauth/`、`gui/tests/add-provider-oauth-url-leak.test.tsx`周辺 | API伝達・両GUIフックの時計制御テスト |
| `docs-site/`の該当provider説明 | ユーザー向け待機・再試行の説明、翻訳矛盾の解消 |
| `docs/test-manual/meta-muse-web-search-content-types.md` | 将来human-test-authorで2件の確認手順を作成 |
| `docs/walkthrough/meta-muse-web-search-content-types.md` | 将来の実装・検証結果 |

再利用する既存関数: `stripMuseSparkUnsupportedWebSearchFields`、`requestMuseDeviceAuthorization`、`pollMuseDeviceToken`、`startLoginFlow`、`getLoginStatus`、`cancelLoginFlow`、`afterOAuthCancellation`、`cancelOAuthLogin`。期限メタデータを追加する場合も既存の取消・保存所有権を置換しない。

- [ ] 実装許可と別作業の状態を確認し、最新upstream取り込み後の基点を記録する。
- [ ] web_search対象範囲と認証待機契約を確定する。
- [ ] 独立した失敗を示す回帰テストを作成し、それぞれの修正で成功へ変わることを確認する。
- [ ] docs-siteとHuman Test手順を更新し、§6の検証を行う。
- [ ] 認証変更の明示的セキュリティレビューを受ける。
- [ ] 許可された場合にのみIssue／PRを作成し、公開内容を精査する。

### 判断メモ（実装者が記入）

- 該当なし。まだ実装していない。

## 6. 検証方法

今回はテストを作成・実行しない。以下は将来実行する検証仕様。

### web_searchの自動テスト

| ケース | 合否基準 |
|---|---|
| direct Meta + 通常1.3、tools／additional_tools | plain web_searchから2フィールドだけを除去し他を保持 |
| baseUrl `https://api.meta.ai` とresponsesPath `/v1/responses` | 同じ送信先として除去 |
| web_search_preview／function | 入力を保持 |
| 対象外ホスト、query・hash・資格情報付きURL | 入力を保持 |
| 既存contributor／free、direct Meta／Zen／Go | 既存除去を維持 |
| 通常1.2、Zen/Go通常1.3 | §9で確定した対象表どおり。対象外なら不変を明示的に検証 |
| 元オブジェクト再利用・非対象ボディ | 入力を破壊しない |

### 認証待機の自動テスト

- fake clock／注入時計、fetch、sleep、Keychainのモックを使う。実API・実Keychainを使わない。
- 有効期限900秒の認証が210秒／310秒／600秒で成功する場合、両GUIが200秒／300秒でcancelを送らず、追加が一度だけ完了すること。
- expires_inが短い・長い・文字列・欠落・不正値の場合に既存正規化と最大30分を維持し、期限を勝手に延長しないこと。
- 期限直前・ちょうど・直後の応答を分け、承認済みtoken成功をローカル時刻だけで捨てないこと。承認後のkey取得中にGUIがdevice期限だけでcancelしないこと。
- authorization_pending、slow_down、429／Retry-After、拒否、expired_token、key取得失敗を分ける。Meta向けポーリングの頻度制限を維持すること。
- 手動cancel／unmount／pagehide／プロバイダー切替／再試行と遅延成功が競合しても旧試行が新試行の画面・資格情報・状態を上書きしないこと。
- statusの単発失敗、連続通信断、ハング、復帰、背景タブ休止、時計差で永久待機や誤成功が起きないこと。
- manual fallbackへ移った際のphase・期限と表示が一致すること。Keychain取込・キー検証の成功、個別タイムアウト、キャンセルを既存テストで維持すること。
- 既存認証済みアカウントを新しいログイン成功と誤認しないこと。addAccount／reauthの既存判定、同一アカウント再追加の通知、別providerのメタデータなし応答を確認すること。
- API応答・ログ・エラーにtoken、キー、内部device_code、非マスクのアカウント情報を新規追加しないこと。

### コマンドとレビュー

取り込み後のファイル配置・scriptsに合わせて最終指定する。v2.60.0基準の候補:

```sh
bun test tests/providers/muse-spark-web-search-compat.test.ts
bun test tests/providers/meta-muse-device.test.ts tests/providers/meta-muse-login-order.test.ts tests/providers/meta-muse-oauth.test.ts
# 新規の期限/APIテストと既存oauthキャンセル関連テストもパス指定で実行
bun test --cwd gui tests/add-provider-oauth-url-leak.test.tsx
# 新規の両GUI認証待機テストも実行
bun run typecheck
bun run test
bun run --cwd gui test
bun run lint:gui
bun run build:gui
bun run privacy:scan
```

共有adapter・認証・serverに触れるため全体テストを必要とする。GUI変更のレビューには画面キャプチャを添付し、PRはSummary／Verification／Checklistを満たす。依存の導入は取り込み後のロックファイルと承認範囲に従う。

### Human Test（将来）

1. human-test-authorで手順書を作成する。実装版・基点SHA・使用画面・開始/終了時刻・終了種別を記録し、認証情報は採取しない。
2. 開発用分離worktree、未使用loopbackポート、専用state/config/authディレクトリ、検証用Codexホームを使う。具体的なCLI引数・環境変数は最新の公式CLI定義で確認する。稼働プロキシ、本番チェックアウト、通常のCodex設定、通常の認証ストアを共有しない。隔離できなければ起動せず手順を修正する。
3. 最初にローカルモックで長い認証待ちを再現し、200秒／300秒超えの成功、期限切れ、cancel、再試行、追加アカウントを確認する。
4. 実Meta認証が別途許可されたときだけ、Humanがブラウザーで認証する。デバイスコードの実期限内で3分20秒・5分を超える操作を確認する。短い実期限なら無理に延長せずモック結果で補う。Keychain経路は別ケースにする。
5. web_searchの実API検証も別途許可後に実施する。通常1.3でweb_search宣言を含む1ターンを送り、2xxと対象400の非発生を確認する。「Hi」で実際に検索ツールが呼ばれたとはみなさない。検索実行までの確認が必要なら明示的な検索要求を別ケースにする。contributorも確認する。
6. 検証プロセスだけを停止し、稼働プロキシが変わっていないことを確かめる。

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

- 実装の明示指示がない。計画保存・計画承認だけでは実装を開始しない。
- 別作業の状態が不明で、upstream取り込みが干渉する可能性が解消していない。
- 通常1.2／Zen/Go通常IDの扱いや認証期限契約など、§9の実装に必要な事項が未確定。
- 開発検証で稼働プロキシ・本番状態・通常の認証ストアを共有する必要が生じる。
- 認証情報の読み取り、実認証・実API利用、Issue投稿／PR公開が未許可。
- gh-ai／tea-aiが専用アカウント・承認・資格情報の検証で停止した。迂回しない。

認証変更にはMAINTAINERS.mdに基づく明示的セキュリティレビューを必要とする。未公開のセキュリティ所見が生じた場合は追跡対象docsへ書かず、`.tmp/`等へ分離する。

### 7-3. 事前承認済みの操作

ここに書いた操作は、確定時のユーザー承認で有効になり、実装中は止まらずに実行する。書かれていない外部への作用（push、PR 作成など）は実行しない。

- 該当なし。現時点で許可されたのはこのworktreeへの計画・作業記録の保存と、計画ファイルのみのローカルcommit。

既定ブランチ（main / master）・本番環境への push、force push、外部公開、および 7-1 の各項目は事前承認できない。

## 8. 完了条件

次をすべて満たすまで実装完了と報告しない。計画の今回の保存完了とは区別する。

- [ ] 最新upstreamの取り込み元タグ・SHAと、両問題の再調査結果がwalkthroughで確認できる。
- [ ] §6のweb_search対象表と認証待機境界のテストが成功し、200秒／300秒での早期取消がなくなった証拠がある。
- [ ] typecheck、全体test、GUI test・lint・build、privacy:scanの成功結果が記録されている。
- [ ] Human Test手順書が存在し、実施ケースと未実施ケースが明記され、必要なHuman確認が完了している。
- [ ] 認証変更に対する明示的セキュリティレビュー記録がある。
- [ ] docs-site・walkthrough・TODOが実装結果と一致する。
- [ ] §5 の実装手順のチェックがすべて付いている

## 9. 未解決事項

| ID | 未解決事項 | 解決方法 |
|---|---|---|
| U1 | 実際に失敗する画面、経過時間、エラー文、稼働バージョン | ユーザーの追加情報。秒単位ならKeychain等を優先切り分け |
| U2 | 通常1.2の追加とZen/Go通常IDへの適用範囲 | direct Meta通常1.3限定案と共有Set案を比較し決定 |
| U3 | 期限APIの形式、phase、承認後・手動入力の有限期限、通信断猶予 | 最新構造契約を読み、時計差・移行互換性・境界テストを具体化 |
| U4 | CLI account-authの短い待機も修正するか | 影響を提示しスコープを決定 |
| U5 | 別作業の状態、最新upstreamの取り込み手順・基点 | 実装開始指示後に既存作業を確認 |
| U6 | 実認証・実API検証と外部共有の範囲 | Human手順・投稿下書きを準備した段階で必要な許可を確認 |
| U7 | 投稿直前のIssue重複再確認と関連PRの最新状態 | Rev.2で通常のghにより既存Issueを検索済み（§2）。今回の条件に一致する報告は見つからず。PR #3964等の最新状態は別途確認が必要 |

保存先の初回確認は回答済み。計画確定・実装開始はいずれも未承認。

## 10. 改訂履歴

- Rev.1 2026/09/21 — 引き継ぎweb_search案を初めてファイル保存。認証タイムアウトの調査・設計候補・テストを追加し、最新upstream取り込みを将来実装の前提に明記。／理由: ユーザーの追加要望とworktree内docsへの保存指定。v2.60.0をローカルタグから読み取り確認し、旧計画のパス・実測範囲を整理。statusはdraftのまま。
- Rev.2 2026/09/21 — §2にupstream Issue検索結果と先行Issueの相違・終了理由を追加、D9を追加、U7を更新。／理由: ユーザー指示「ghコマンドでupstreamにこの件のISSUEが存在するか確認」「gh-aiは使わない」。一致するIssueは検索範囲では未発見。外部投稿・実装は行わずdraftを維持。
