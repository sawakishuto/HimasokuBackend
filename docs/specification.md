# HimaSoku Backend 仕様書

「暇」をグループ内で共有し、プッシュ通知で誘い合うアプリのバックエンド API。

- 最終更新: 2026-08-20
- 対象コードベース: リファクタ後の `main`

---

## 1. 概要

| 項目 | 内容 |
|------|------|
| フレームワーク | Ruby on Rails 7.1（API モード） |
| 言語 | Ruby 3.3.7 |
| DB | PostgreSQL 15+ |
| キャッシュ | Redis（Firebase 公開鍵のキャッシュに使用） |
| 認証 | Firebase Authentication（ID トークン検証） |
| プッシュ通知 | Apple APNS（`apnotic` gem + P8 トークン認証） |
| API ドキュメント | Swagger UI（`/api-docs`、`rswag`） |
| 実行環境 | Docker / Docker Compose |

主なユースケース:

1. iOS クライアントが Firebase でサインインし、ID トークンを付けて API を呼ぶ。
2. ユーザー・デバイストークン・グループ・メンバーシップを登録する。
3. あるユーザーが「暇」を共有すると、同じグループのメンバーへインタラクティブ通知（参加 / 辞退）が飛ぶ。
4. 参加 / 辞退のアクションが返ってくると、共有元へ結果通知を送る。

---

## 1.1 関連リポジトリ

| リポジトリ | 役割 |
|-----------|------|
| `sawakishuto/HimasokuBackend`（本リポジトリ） | Rails API サーバー |
| `sawakishuto/HimaSoku` | iOS クライアント（SwiftUI + Alamofire + Firebase Auth） |
| `sawakishuto/himasoku_terraform` | GCP インフラ（Terraform） |

### デプロイ / インフラ（GCP）

| 項目 | 値 |
|------|----|
| 実行環境 | Cloud Run（`asia-northeast1`） |
| 公開 URL | `https://himasoku-234324210193.asia-northeast1.run.app`（iOS クライアントの `baseURL`） |
| データベース | Cloud SQL for PostgreSQL 14（`himasoku-db`、プライベート IP） |
| ネットワーク | VPC + Serverless VPC Access Connector（`himasoku-vpc-connector`） |
| CI/CD | GitHub Actions（Terraform）＋ Workload Identity |

---

## 1.2 リクエストパラメータの形式

iOS クライアントは**フラットな JSON** を送信する（例: `{"firebase_uid": "...", "name": "..."}`）。
一方 `users` / `devices` / `users_groups` コントローラは `params.require(:モデル名)` 形式の
ストロングパラメータを使うため、`config/initializers/wrap_parameters.rb` で
**ParamsWrapper を有効化**し、受信 JSON を各コントローラのモデルキー
（`:user` / `:device` / `:users_group`）配下へ自動ラップしている。

- クライアントはフラット JSON を送るだけでよい（`{"user": {...}}` のネストは不要）。
- トップレベルのキーは保持されるため、`params[:x]` を直接読む `groups` /
  `notifications` コントローラには影響しない。

> この初期化子が無いと ParamsWrapper は無効になり、`POST /users` `POST /devices`
> `POST /users_groups` がフラット JSON に対して `400 ParameterMissing` を返す。

---

## 2. 認証

すべてのエンドポイントは `GET /test/apns` と `GET /up` を除き認証必須。

- ヘッダ: `Authorization: Bearer <Firebase ID Token>`
- 検証: `FirebaseIdToken::TokenVerifier`（`config/initializers/firebase_id_token.rb`）
  - Google の公開鍵（`securetoken@system` の x509 証明書）を Redis にキャッシュし、`RS256` で ID トークンを検証する。
  - 検証成功時、ペイロードの `sub` を `firebase_uid` として扱う。
- 自動プロビジョニング（`ApplicationController#find_or_provision_user`）:
  - 未登録の `firebase_uid` なら `users` レコードを新規作成（`email` / `name` も設定）。
  - 既存ユーザーで `name` が空なら、トークンの `name`（無ければ `display_name`、無ければメールのローカル部）で補完。
- 検証失敗・トークン無しの場合は `401 Unauthorized`（`{ "error": "Unauthorized" }`）。

認証を通ったユーザーはコントローラ内で `current_user` として参照できる。

---

## 3. データモデル

主キーはアプリ側の識別子をそのまま使う設計（`users.firebase_uid`, `groups.group_id`, `user_devices.device_id`, `group_users.uuid`）。

### users
| カラム | 型 | 備考 |
|--------|----|------|
| `firebase_uid` | string | **主キー**。Firebase UID |
| `name` | string | 表示名 |
| `email` | string | メールアドレス |
| `created_at` / `updated_at` | datetime | |

### user_devices
| カラム | 型 | 備考 |
|--------|----|------|
| `device_id` | string | **主キー**。APNS デバイストークン（`apns_token` として別名参照可） |
| `firebase_uid` | string | 外部キー → `users` |

- `device_id` は presence + uniqueness バリデーションあり。

### groups
| カラム | 型 | 備考 |
|--------|----|------|
| `group_id` | string | **主キー** |
| `name` | string | グループ名 |

### group_users（中間テーブル）
| カラム | 型 | 備考 |
|--------|----|------|
| `uuid` | string | **主キー** |
| `group_id` | string | 外部キー → `groups` |
| `firebase_uid` | string | 外部キー → `users` |

- `(group_id, firebase_uid)` はユニーク制約。

### 関連

```
User  1--*  UserDevice
User  *--*  Group   (through GroupUser)
```

- `User#summary` → `{ id: firebase_uid, name: name }`
- `Group#summary` → `{ id: group_id, name: name }`
（API レスポンスの軽量表現に使用）

> **レガシー（未使用）テーブル**: `simple_users` / `simple_groups` / `simple_group_users` / `simple_user_devices` がスキーマに残っているが、対応するモデル・ルート・コードは存在しない。現行仕様では未使用。

---

## 4. API エンドポイント

ベース URL 直下にリソースを配置。特記なき成功レスポンスは JSON。

### 4.1 ユーザー

#### `GET /users`
全ユーザーを返す（AR レコードそのまま）。

#### `GET /users/:id`
`id` = `firebase_uid`。存在しなければ `404 { "error": "User not found" }`。

#### `POST /users`
冪等な作成 / 補完。フラット JSON で送信（ParamsWrapper が `:user` へラップ）。
```json
{ "firebase_uid": "abc123", "name": "田中", "email": "tanaka@example.com" }
```
- 既存ユーザー: 空の `name` / `email` のみ補完し `200`。
- 新規: 作成し `201`。バリデーションエラー時 `422`。

### 4.2 デバイス

#### `GET /devices/:id`
`id` = `device_id`。存在しなければ `404`。

#### `POST /devices`
フラット JSON で送信（ParamsWrapper が `:device` へラップ）。
```json
{ "firebase_uid": "abc123", "device_id": "<APNSトークン>" }
```
- 既存 `device_id`: そのまま `200`。
- 新規: `201`。エラー時 `422`。

### 4.3 グループ

#### `GET /groups`
```json
{ "groups": [ { "id": "g1", "name": "ゼミ" } ] }
```

#### `GET /groups/:id`
```json
{ "id": "g1", "name": "ゼミ" }
```
存在しなければ `404`（Rails 標準の `RecordNotFound` ハンドリング）。

#### `POST /groups`
`group_id` で `find_or_create_by`（トップレベル params）。
```json
{ "group_id": "g1", "name": "ゼミ" }
```
成功時 `201`（グループレコード）、失敗時 `422`。

### 4.4 メンバーシップ（users_groups）

#### `GET /users_groups`
全メンバーシップを返す。
```json
[ { "user_id": "abc123", "group_id": "g1", "group_name": "ゼミ" } ]
```

#### `GET /users_groups/:id`
全 `(user_id, group_id)` ペアの配列を返す（`:id` は現状参照されない）。
```json
[ ["abc123", "g1"], ["def456", "g1"] ]
```

#### `POST /users_groups`
冪等なメンバーシップ作成。フラット JSON で送信（ParamsWrapper が `:users_group` へラップ）。
`uuid` はクライアントが生成する（iOS 側は `UUID().uuidString`）。
```json
{ "uuid": "…", "firebase_uid": "abc123", "group_id": "g1" }
```
- 既存の関係: `200`。
- 新規: `201`。エラー時 `422`。

#### `GET /groups/:group_id/users`
グループ所属ユーザー一覧。
```json
{ "group": { "id": "g1", "name": "ゼミ" },
  "users": [ { "id": "abc123", "name": "田中" } ] }
```

#### `GET /users/:user_id/groups`
ユーザーの所属グループ一覧。
```json
{ "groups": [ { "id": "g1", "name": "ゼミ" } ] }
```

### 4.5 通知

通知系の成功レスポンスは共通の集計フォーマット:
```json
{
  "message": "Notifications sent successfully",
  "total_tokens": 3,
  "successful": 2,
  "failed": 1,
  "details": [
    { "token": "...", "status": "success", "notification_id": "uuid", "apns_id": "..." },
    { "token": "...", "status": "failed",  "error": { "reason": "BadDeviceToken" } }
  ]
}
```
`status` は `success` / `failed`（APNS が拒否）/ `error`（送信中に例外）。

#### `POST /notifications/group/:group_id`
グループ内の**送信者を除く**全員へ「暇共有」インタラクティブ通知を送る。
```json
{ "firebase_uid": "sender-uid", "name": "田中", "durationTime": 60 }
```
- 本文: `「{name}が暇を共有しています。\n {durationTime}」`
- グループ未存在: `404 { "error": "Group not found" }`。

#### `POST /notifications/user/:firebase_uid`
特定ユーザーの全デバイスへインタラクティブ通知。
```json
{ "title": "お知らせ", "body": "本文", "data": { "任意": "値" } }
```
ユーザー未存在: `404`。

#### `POST /notifications/custom`
デバイストークンを直接指定して送信。
```json
{ "device_tokens": ["...", "..."], "title": "件名", "body": "本文", "data": {} }
```

#### `POST /notifications/response`
インタラクティブ通知のアクション応答を処理し、共有元へ結果を通知する。
```json
{
  "firebase_uid": "responder-uid",
  "action_identifier": "JOIN_ACTION",
  "sender_firebase_uid": "sender-uid",
  "sender_name": "田中",
  "group_id": "g1"
}
```
- `action_identifier`: `JOIN_ACTION`（参加）/ `DECLINE_ACTION`（辞退）。それ以外は `400`。
- 応答:
  ```json
  { "message": "参加しました！", "action": "joined", "user": "佐藤", "group_id": "g1" }
  ```
- 共有元（`sender_firebase_uid`）へ、参加なら「{名前}が共感しています！」、辞退なら「{名前}は今は忙しいみたいです😢」をシンプル通知で送る。

### 4.6 その他

| メソッド | パス | 内容 |
|----------|------|------|
| GET | `/test/apns` | **認証不要**。APNS の JWT 生成が成功するかの簡易ヘルスチェック。`{ "success": true, "message": "..." }`。秘匿情報は返さない |
| GET | `/up` | Rails ヘルスチェック（起動確認用、200/500） |
| GET | `/api-docs` | Swagger UI |

---

## 5. APNS プッシュ通知の仕組み

実装は `config/initializers/apns.rb`（`APNS` モジュール）と `app/services/notification_service.rb`。

### 認証方式
- P8 認証キーによるトークン（JWT）認証。`Apnotic::ConnectionPool` でコネクションを再利用する。
- ゲートウェイは `APNS_ENVIRONMENT`（未設定時は `Rails.env`）が `production` なら本番、それ以外は Sandbox。

### JWT（重要）
- APNS のプロバイダトークンは **ES256** 署名で、JOSE 仕様（RFC 7518）により **生の `r‖s`（64 バイト）** が必要。
- `apnotic` 1.7.2 は署名を ASN.1(DER) 形式で出力するバグがあり、そのままだと APNS に `InvalidProviderToken` で拒否される。
- `config/initializers/apnotic_es256_patch.rb` で `Apnotic::ProviderToken#signature` を差し替え、DER → 生 `r‖s` に変換して修正している。

### 送信 API（`APNS.push`）
```ruby
APNS.push(device_token,
          alert: { title:, body: }, badge: 1, sound: 'default',
          category: nil, mutable_content: false, content_available: false,
          custom: {}, priority: 10, topic: APNS.bundle_id)
# => { success:, status:, body:, headers:, apns_id: }
```

### 通知テンプレート（`NotificationService`）
| テンプレート | 用途 | aps の主なキー |
|--------------|------|----------------|
| インタラクティブ | 暇共有 / ユーザー通知 / カスタム | `category: HIMASOKU_INVITE`, `mutable-content: 1`, `content-available: 1`, `badge`, `sound` |
| シンプル | 参加 / 辞退の結果通知 | `content-available: 1`, `badge`, `sound`（category なし） |

- どの通知にも一意な `notification_id`（UUID）を custom フィールドとして付与する。
- インタラクティブ通知のカテゴリ `HIMASOKU_INVITE` はクライアント側で「わかる😮」(`JOIN_ACTION`) / 「今は暇じゃない😢」(`DECLINE_ACTION`) の 2 ボタンに対応（詳細は `docs/interactive_notifications.md`）。

### カスタムペイロードのキー契約（重要）

通知の custom フィールド（`aps` の外側）のキーは iOS クライアント（`AppDelegate`）が
参照するため、**キー名・型を変更すると通知処理が静かに壊れる**。以下は固定契約。

**暇共有（招待）通知** — `POST /notifications/group/:group_id` 由来:

| キー | 型 | 用途（クライアント） |
|------|----|----------------------|
| `notification_id` | String | 未応答検知の待機タスク ID |
| `sender_firebase_uid` | String | 応答 API の送信先 |
| `sender_name` | String | 表示・応答 API |
| `group_id` | String | 応答 API |
| `durationTime` | String | 応答 API（**String 必須**。数値だとクライアントの `as? String` が nil になり待機処理が中断する） |

**アクション結果通知** — `POST /notifications/response` の後に共有元へ送る:

| キー | 型 | 用途（クライアント） |
|------|----|----------------------|
| `action` | String | `"JOIN"` / `"DECLINE"`（フォアグラウンド即時処理の分岐） |
| `user_name` | String | 「共感した人」名の保存 |
| `user_id` | String | 参考情報 |

> クライアントは招待通知で上記 5 キーが揃わないと待機処理を中断する（通知表示自体は行う）。
> バックエンドは常にこれらを含めること。

---

## 6. 環境変数

| 変数 | 必須 | 説明 |
|------|------|------|
| `APNS_TEAM_ID` | ✅ | Apple Developer Team ID |
| `APNS_KEY_ID` | ✅ | P8 認証キーの Key ID |
| `APNS_P8_CONTENT` | ✅ | P8 認証キーの内容（PEM 文字列） |
| `APNS_BUNDLE_ID` | | トピック（既定: `com.sawaki.HimaSoku`） |
| `APNS_ENVIRONMENT` | | `production` / `sandbox`（既定: `Rails.env`） |
| `APNS_POOL_SIZE` | | コネクションプールのサイズ（既定: 5） |
| `REDIS_URL` | | Firebase 公開鍵キャッシュ用（既定: `redis://redis:6379/1`） |
| `ALLOWED_ORIGINS` | | 本番の CORS 許可オリジン（カンマ区切り）。開発は全許可 |
| DB 関連 | | `config/database.yml` に準拠 |

---

## 7. エラーレスポンス

| ステータス | 例 | 発生条件 |
|-----------|----|---------|
| `401` | `{ "error": "Unauthorized" }` | トークン無し / 検証失敗 |
| `400` | `{ "error": "Unknown action identifier" }` | 不正な `action_identifier` |
| `404` | `{ "error": "User not found" }` 等 | リソース未存在 |
| `422` | `{ "errors": [...] }` / モデルの errors | バリデーション失敗 |
| `500` | `{ "error": "Failed to send notifications" }` 等 | 想定外の例外 |
