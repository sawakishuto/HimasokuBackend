# GitHub Secrets 設定ガイド

## 🔐 必要な Secrets

### Option 1: Workload Identity Federation（推奨）

```bash
# GitHub Secretsに設定する値
WIF_PROVIDER=projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
WIF_SERVICE_ACCOUNT=SERVICE_ACCOUNT_NAME@PROJECT_ID.iam.gserviceaccount.com
```

### Option 2: Service Account Key（フォールバック）

```bash
# GitHub Secretsに設定する値
GCP_SA_KEY={"type":"service_account","project_id":"himasoku",...}
```

## 🛠️ Workload Identity Federation セットアップ

### Step 1: Workload Identity Pool を作成

```bash
# Workload Identity Poolを作成
gcloud iam workload-identity-pools create "github-pool" \
  --project="himasoku" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# GitHub用のProviderを作成
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="himasoku" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### Step 2: Service Account に権限を付与

```bash
# Service Accountを作成（まだない場合）
gcloud iam service-accounts create github-actions \
  --project="himasoku" \
  --display-name="GitHub Actions Service Account"

# 必要な権限を付与
gcloud projects add-iam-policy-binding himasoku \
  --member="serviceAccount:github-actions@himasoku.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding himasoku \
  --member="serviceAccount:github-actions@himasoku.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding himasoku \
  --member="serviceAccount:github-actions@himasoku.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Workload Identity Federationの権限を付与
gcloud iam service-accounts add-iam-policy-binding \
  --project="himasoku" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_USERNAME/himasoku_backend" \
  github-actions@himasoku.iam.gserviceaccount.com
```

### Step 3: GitHub Secrets を設定

```bash
# プロジェクト番号を取得
PROJECT_NUMBER=$(gcloud projects describe himasoku --format="value(projectNumber)")

# WIF_PROVIDERの値
echo "WIF_PROVIDER=projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"

# WIF_SERVICE_ACCOUNTの値
echo "WIF_SERVICE_ACCOUNT=github-actions@himasoku.iam.gserviceaccount.com"
```

## ⚠️ 重要事項

1. **リポジトリ名を正確に指定**: `YOUR_GITHUB_USERNAME/himasoku_backend`
2. **プロジェクト番号を使用**: プロジェクト ID ではなくプロジェクト番号
3. **権限の最小化**: 必要最小限の権限のみ付与

## 🔍 トラブルシューティング

### エラー: "workload_identity_provider" or "credentials_json"

- どちらか一つの Secrets のみ設定してください
- 両方設定されている場合は、WIF_PROVIDER を優先します

### エラー: "Token request failed"

- Service Account の権限を確認
- Workload Identity Federation の設定を確認
- リポジトリ名が正確か確認
