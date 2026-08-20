# 整合性・改善に関する発見事項

iOS クライアント（`sawakishuto/HimaSoku`）・インフラ（`sawakishuto/himasoku_terraform`）と
突き合わせて見つかった、要対応事項のメモ。**自動修正済み**と**要判断（未修正）**に分ける。

最終更新: 2026-08-20

---

## 自動修正済み

| 項目 | 内容 | 対応 |
|------|------|------|
| ParamsWrapper 無効 | クライアントはフラット JSON を送るが `users`/`devices`/`users_groups` は `require(:モデル)` を要求。初期化子欠落で `400 ParameterMissing` になっていた | `config/initializers/wrap_parameters.rb` を追加 |
| Redis 認証情報のハードコード | `config/initializers/redis.rb` にパスワード付き接続文字列が直書き（到達不能なデッドフォールバック） | 該当行を `ENV["REDIS_URL"]` のみに変更して削除 |
| デバッグ出力 | `firebase_id_token.rb` の `puts` / コメントアウト済み `# puts` | logger 化・削除 |
| APNS env 名の不一致 | バックエンドは `APNS_P8_CONTENT` を読むが、Terraform/Cloud Run は `APNS_AUTH_KEY_CONTENT` を設定。本番で `KeyError` → APNS が起動不能だった可能性 | `apns.rb#p8_content` を両方の env 名を許容するよう変更 |

---

## 要判断（未修正・認証クリティカルパスのため保留）

### 1. Redis 認証情報のローテーション【セキュリティ / 重要】
Redis 接続文字列（パスワード付き）が **2 箇所に平文で存在**していた:
- `config/initializers/redis.rb`（削除済み・到達不能なデッドコードだった）
- `himasoku_terraform/main.tf` の Cloud Run `env { name = "REDIS_URL" ... }`（**現用の値**）

どちらも git 履歴に残るため、当該 Redis の**認証情報をローテーション**し、Terraform 側は
値直書きではなく Secret Manager 参照（`value_source.secret_key_ref`）に移すことを推奨。

### 1.5 APNS の env 名不一致【本番影響 / 重要】
Terraform は Cloud Run に `APNS_AUTH_KEY_CONTENT`（Secret `apns-key-file`）を渡すが、
アプリは `APNS_P8_CONTENT` を読んでいた。本番では未設定 → `KeyError` で APNS が動かない。
- コード側で両名を許容するよう修正済み（`apns.rb#p8_content`）。
- 望ましくは infra とコードで env 名を統一する（どちらかに寄せる）。
- 併せて Terraform に **`APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_BUNDLE_ID`** は渡っているが、
  ゲートウェイ判定に使う `APNS_ENVIRONMENT=production` は設定済み（一致・良好）。

### 2. `firebase_id_token.rb#save_certs_to_redis` のフォールバックが壊れている
```ruby
def save_certs_to_redis
  uri = URI.parse(CERTS_URI)
  response = Net::HTTP.get_response(uri)   # ← レスポンス「オブジェクト」を返す
  certs = JSON.parse(response)             # ← response.body でないと解析できない
  @redis.set("firebase_auth_certificates", certs.to_json)  # ← 戻り値は "OK"
end
```
- 呼び出し側は `certs = save_certs_to_redis`（= `"OK"`）を受け取り、直後に
  `JSON.parse("OK")` で `JSON::ParserError` を起こす。
- そのため **Redis キャッシュミス時（キャッシュ失効・削除・未ウォーム時）に認証が 401 になる**。
  通常は起動時の `redis.rb` がキャッシュを埋めるため露見しないが、キャッシュが消えると
  再起動まで全リクエストが認証失敗する可能性がある。
- 想定修正（**要レビュー・テスト**）:
  ```ruby
  def save_certs_to_redis
    response = Net::HTTP.get(URI.parse(CERTS_URI))  # body(String) を返す
    @redis.set("firebase_auth_certificates", JSON.parse(response).to_json)
    response  # or certs json string を返す
  rescue => e
    Rails.logger.error "Failed to fetch Firebase certs: #{e.message}"
    nil
  end
  ```
  加えて呼び出し側の `certs = save_certs_to_redis; JSON.parse(certs)` の受け渡しを整える。
  認証全体に影響するため、ローカル/ステージングでの検証後に適用したい。

### 3. Redis URL フォールバックの不一致
`redis.rb` と `firebase_id_token.rb` で未設定時の既定 URL が異なる
（前者は削除済み、後者は `redis://redis:6379/1`）。本番は `REDIS_URL` 必須の想定なので、
どちらも「未設定なら明示エラー」に寄せると安全。

### 4. Terraform / GCP のハードニング（別リポジトリ・参考）
`himasoku_terraform/main.tf` で気づいた点:
- Cloud SQL `backup_configuration { enabled = false }` … バックアップ無効。障害時に復旧不可。
- Cloud SQL `require_ssl = false` … プライベート IP のみ（`ipv4_enabled = false`）なので露出は低いが、SSL 必須が望ましい。
- `authorized_networks { value = "0.0.0.0/0" }` が定義されているが `ipv4_enabled = false` のため実効なし（設定の残骸）。
- `RAILS_SECRET_KEY_BASE`（secret `rails_secret_key_base`）と `SECRET_KEY_BASE`（secret `SECRET_KEY_BASE`）が両方定義され重複・紛らわしい。どちらを使うか整理を。

### 5. iOS クライアント側の堅牢性（別リポジトリ・参考）
`AppDelegate.didReceive` で `senderFirebaseUID!` 等を強制アンラップしている。
バックエンドがキーを 1 つでも欠くとクラッシュする。バックエンド側は
[カスタムペイロードのキー契約](specification.md#カスタムペイロードのキー契約重要)を厳守すること。
