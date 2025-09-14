#!/bin/bash

# Workload Identity Federation セットアップスクリプト

set -e

PROJECT_ID="himasoku"
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SERVICE_ACCOUNT_NAME="github-actions"
GITHUB_REPO="YOUR_GITHUB_USERNAME/himasoku_backend"  # ← 実際のリポジトリ名に変更してください

echo "🔍 Current project information:"
echo "Project ID: $PROJECT_ID"

# プロジェクト番号を取得
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"

# 現在のプロジェクトを設定
gcloud config set project $PROJECT_ID

echo ""
echo "📋 Checking existing Workload Identity Pools..."
gcloud iam workload-identity-pools list --location="global" --format="table(name,displayName,state)" || echo "No pools found or API not enabled"

echo ""
echo "📋 Checking existing Service Accounts..."
gcloud iam service-accounts list --format="table(email,displayName)" --filter="email:$SERVICE_ACCOUNT_NAME@*"

echo ""
echo "🚀 Setting up Workload Identity Federation..."

# Step 1: IAM API を有効化
echo "Enabling IAM API..."
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Step 2: Workload Identity Pool を作成
echo "Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create $POOL_ID \
  --project=$PROJECT_ID \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Pool for GitHub Actions authentication"

# Step 3: GitHub Provider を作成
echo "Creating GitHub Provider..."
gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
  --project=$PROJECT_ID \
  --location="global" \
  --workload-identity-pool=$POOL_ID \
  --display-name="GitHub Provider" \
  --description="Provider for GitHub Actions" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Step 4: Service Account を作成
echo "Creating Service Account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
  --project=$PROJECT_ID \
  --display-name="GitHub Actions Service Account" \
  --description="Service account for GitHub Actions deployments"

# Step 5: Service Account に必要な権限を付与
echo "Granting permissions to Service Account..."
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Cloud Run 管理権限
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/run.admin"

# Artifact Registry 書き込み権限
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/artifactregistry.writer"

# Cloud SQL クライアント権限
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/cloudsql.client"

# Secret Manager アクセス権限
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/secretmanager.secretAccessor"

# Service Account Token Creator権限
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator"

# Step 6: Workload Identity Federation の権限を付与
echo "Setting up Workload Identity Federation binding..."
gcloud iam service-accounts add-iam-policy-binding \
  --project=$PROJECT_ID \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_REPO" \
  $SERVICE_ACCOUNT_EMAIL

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📋 GitHub Secrets to configure:"
echo "WIF_PROVIDER=projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
echo "WIF_SERVICE_ACCOUNT=$SERVICE_ACCOUNT_EMAIL"
echo ""
echo "⚠️  Important: Update GITHUB_REPO variable in this script with your actual repository name!"
echo "   Current: $GITHUB_REPO"
echo "   Format: username/repository-name"
echo ""
echo "🔍 Verification commands:"
echo "gcloud iam workload-identity-pools list --location=global"
echo "gcloud iam service-accounts list --filter='email:$SERVICE_ACCOUNT_EMAIL'"
