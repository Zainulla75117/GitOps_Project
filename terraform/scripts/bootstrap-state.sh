#!/usr/bin/env bash

set -euo pipefail

BUCKET_NAME="gitops-tfstate-ap-south-1"
DYNAMODB_TABLE="gitops-tf-lock"
REGION="ap-south-1"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Terraform Remote State Bootstrap — ap-south-1${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

if ! command -v aws &> /dev/null; then
  error "AWS CLI not found. Install it from https://aws.amazon.com/cli/"
  exit 1
fi

CALLER=$(aws sts get-caller-identity --query "Arn" --output text 2>/dev/null || true)
if [[ -z "$CALLER" ]]; then
  error "AWS credentials not configured or invalid. Run: aws configure"
  exit 1
fi
info "Authenticated as: $CALLER"
echo ""

echo -e "${CYAN}--- S3 Bucket ---${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
  success "Bucket already exists: $BUCKET_NAME"
else
  info "Creating bucket: $BUCKET_NAME"
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --output text > /dev/null
  success "Bucket created: $BUCKET_NAME"
fi

VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query "Status" --output text 2>/dev/null || echo "None")
if [[ "$VERSIONING" == "Enabled" ]]; then
  success "Versioning already enabled"
else
  info "Enabling versioning on bucket"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
  success "Versioning enabled"
fi

ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" 2>/dev/null | grep -c "AES256" || true)
if [[ "$ENCRYPTION" -gt 0 ]]; then
  success "Server-side encryption already enabled (AES256)"
else
  info "Enabling AES256 encryption on bucket"
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
  success "Encryption enabled"
fi

PUBLIC_BLOCK=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null || echo "not_set")
if echo "$PUBLIC_BLOCK" | grep -q '"BlockPublicAcls": true' 2>/dev/null; then
  success "Public access block already enabled"
else
  info "Blocking all public access on bucket"
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
      "BlockPublicAcls": true,
      "IgnorePublicAcls": true,
      "BlockPublicPolicy": true,
      "RestrictPublicBuckets": true
    }'
  success "Public access blocked"
fi

echo ""
echo -e "${CYAN}--- DynamoDB Table ---${NC}"
TABLE_STATUS=$(aws dynamodb describe-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$REGION" \
  --query "Table.TableStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$TABLE_STATUS" == "ACTIVE" ]]; then
  success "DynamoDB table already exists and is ACTIVE: $DYNAMODB_TABLE"
elif [[ "$TABLE_STATUS" == "CREATING" ]]; then
  warn "DynamoDB table is still being created. Wait and re-run."
else
  info "Creating DynamoDB table: $DYNAMODB_TABLE"
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --output text > /dev/null

  info "Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
  success "DynamoDB table created and ACTIVE: $DYNAMODB_TABLE"
fi

echo ""
echo -e "${CYAN}--- Summary ---${NC}"
echo ""
echo -e "  S3 Bucket      : ${GREEN}s3://$BUCKET_NAME${NC}"
echo -e "  DynamoDB Table : ${GREEN}$DYNAMODB_TABLE${NC}"
echo -e "  Region         : ${GREEN}$REGION${NC}"
echo ""
success "Remote state backend is ready. You can now run: terraform init"
echo ""
