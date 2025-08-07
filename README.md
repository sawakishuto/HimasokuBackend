# Himasoku Backend

Rails API application for group membership management with PostgreSQL.

## System Requirements

- Ruby 3.3.7
- PostgreSQL 15+
- Docker & Docker Compose (recommended)

## Database Schema

- **Users**: ユーザー管理
  - `uid`: プライマリーキー
- **UserDevices**: ユーザーデバイス管理
  - `device_id`: プライマリーキー
  - `uid`: 外部キー（Users）
- **Groups**: グループ管理
  - `group_id`: プライマリーキー
  - `name`: グループ名
- **GroupUsers**: グループメンバーシップ管理
  - `uuid`: プライマリーキー
  - `group_id`: 外部キー（Groups）
  - `uid`: 外部キー（Users）

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

### Users
- `GET /users` - Get all users
- `GET /users/:id` - Get a specific user
- `POST /users` - Create a new user

### Devices
- `GET /devices/:id` - Get a specific device
- `POST /devices` - Create a new device

### Group Membership
- `GET /users/:user_id/groups` - Get groups for a user
- `GET /groups/:group_id/users` - Get members of a group
- `GET /users_groups` - Get all user-group relationships
- `POST /users_groups` - Create a new user-group relationship

## Environment Variables

| Variable    | Description       | Default     |
| ----------- | ----------------- | ----------- |
| DB_HOST     | Database host     | localhost   |
| DB_PORT     | Database port     | 5432        |
| DB_USERNAME | Database username | postgres    |
| DB_PASSWORD | Database password | password    |
| RAILS_ENV   | Rails environment | development |
# hima_soku_backend
# HimasokuBackend
# HimasokuBackend
# HimasokuBackend
