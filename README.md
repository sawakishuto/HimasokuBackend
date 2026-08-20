# Himasoku Backend

「暇」をグループ内で共有し、プッシュ通知で誘い合う HimaSoku アプリの Rails API サーバー。

> 詳細な仕様（全 API・認証・APNS・インフラ・クライアント契約）は
> [`docs/specification.md`](docs/specification.md) を参照。整合性に関する既知の課題は
> [`docs/integrity-findings.md`](docs/integrity-findings.md) にまとめている。

## System Requirements

- Ruby 3.3.7
- PostgreSQL 14+（本番は Cloud SQL for PostgreSQL 14）
- Redis（Firebase 公開鍵のキャッシュに使用）
- Docker & Docker Compose (recommended)

## Database Schema

主キーはアプリ側の識別子をそのまま使用する。

- **users**: ユーザー管理
  - `firebase_uid`: プライマリーキー（Firebase UID）
  - `name`, `email`
- **user_devices**: デバイストークン管理
  - `device_id`: プライマリーキー（APNS デバイストークン）
  - `firebase_uid`: 外部キー（users）
- **groups**: グループ管理
  - `group_id`: プライマリーキー
  - `name`: グループ名
- **group_users**: グループメンバーシップ（中間テーブル）
  - `uuid`: プライマリーキー
  - `group_id`: 外部キー（groups）
  - `firebase_uid`: 外部キー（users）

> `simple_users` / `simple_groups` / `simple_group_users` / `simple_user_devices` は
> 旧スキーマの名残で、現行コードからは未使用。

## Setup with Docker Compose (Recommended)

1. **Clone and navigate to project**

   ```bash
   git clone <repository-url>
   cd himasoku_backend
   ```

2. **Start services**

   ```bash
   docker-compose up -d
   ```

3. **Setup database**

   ```bash
   docker-compose exec app rails db:create
   docker-compose exec app rails db:migrate
   docker-compose exec app rails db:seed  # Optional: Load sample data
   ```

4. **Access the application**
   - API: http://localhost:3000
   - Swagger UI: http://localhost:3000/api-docs
   - PostgreSQL: localhost:5432

## Manual Setup (Without Docker)

1. **Install dependencies**

   ```bash
   bundle install
   ```

2. **Setup environment variables**

   ```bash
   cp env.example .env
   # Edit .env file with your database credentials
   ```

3. **Setup database**

   ```bash
   rails db:create
   rails db:migrate
   rails db:seed  # Optional
   ```

4. **Start server**
   ```bash
   rails server
   ```

## Development

**Stop services**

```bash
docker-compose down
```

**View logs**

```bash
docker-compose logs -f app
```

**Access Rails console**

```bash
docker-compose exec app rails console
```

**Run tests**

```bash
docker-compose exec app rails test
```

## API Documentation

**Swagger UI**: http://localhost:3000/api-docs

## API Endpoints

`GET /test/apns` と `GET /up` を除き、すべて `Authorization: Bearer <Firebase ID Token>` が必須。

### Users
- `GET /users` - 全ユーザー取得
- `GET /users/:id` - 特定ユーザー取得（`:id` = firebase_uid）
- `POST /users` - ユーザー作成 / 補完

### Devices
- `GET /devices/:id` - 特定デバイス取得
- `POST /devices` - デバイストークン登録

### Groups
- `GET /groups` - 全グループ取得
- `GET /groups/:id` - 特定グループ取得
- `POST /groups` - グループ作成

### Group Membership
- `GET /users/:user_id/groups` - ユーザーの所属グループ一覧
- `GET /groups/:group_id/users` - グループのメンバー一覧
- `GET /users_groups` - 全メンバーシップ取得
- `POST /users_groups` - メンバーシップ作成

### Notifications（APNS プッシュ通知）
- `POST /notifications/group/:group_id` - グループへ暇共有通知（送信者を除く）
- `POST /notifications/user/:firebase_uid` - 特定ユーザーへ通知
- `POST /notifications/custom` - デバイストークン指定で送信
- `POST /notifications/response` - 参加 / 辞退アクションの処理

### その他
- `GET /test/apns` - APNS JWT 生成のヘルスチェック（認証不要）
- `GET /up` - Rails ヘルスチェック
- `GET /api-docs` - Swagger UI

> リクエスト / レスポンスの詳細は [`docs/specification.md`](docs/specification.md) を参照。

## Environment Variables

DB 系のほか、Firebase 認証・Redis・APNS の設定が必要。主なもの:

| Variable          | Description                            | Default            |
| ----------------- | -------------------------------------- | ------------------ |
| DB_HOST           | Database host                          | localhost          |
| DB_PORT           | Database port                          | 5432               |
| DB_USERNAME       | Database username                      | postgres           |
| DB_PASSWORD       | Database password                      | password           |
| RAILS_ENV         | Rails environment                      | development        |
| REDIS_URL         | Redis 接続 URL（Firebase 鍵キャッシュ）| redis://redis:6379/1 |
| APNS_TEAM_ID      | Apple Developer Team ID                | —                  |
| APNS_KEY_ID       | P8 認証キーの Key ID                   | —                  |
| APNS_P8_CONTENT   | P8 認証キーの内容（`APNS_AUTH_KEY_CONTENT` でも可） | —     |
| APNS_BUNDLE_ID    | トピック                               | com.sawaki.HimaSoku |
| APNS_ENVIRONMENT  | production / sandbox                   | Rails.env          |

> 全変数と APNS の詳細は [`docs/specification.md`](docs/specification.md#6-環境変数) を参照。
