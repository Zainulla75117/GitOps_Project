param(
    [switch]$CheckOnly
)

$BucketName    = "gitops-tfstate-ap-south-1"
$DynamoTable   = "gitops-tf-lock"
$Region        = "ap-south-1"

function Write-Info    ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok      ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err     ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Terraform Remote State Bootstrap - ap-south-1" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Err "AWS CLI not found. Download from https://aws.amazon.com/cli/"
    exit 1
}

$caller = aws sts get-caller-identity --query "Arn" --output text 2>$null
if (-not $caller) {
    Write-Err "AWS credentials not configured or invalid. Run: aws configure"
    exit 1
}
Write-Info "Authenticated as: $caller"
Write-Host ""

Write-Host "--- S3 Bucket ---" -ForegroundColor Cyan

$bucketExists = $false
try {
    aws s3api head-bucket --bucket $BucketName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) { $bucketExists = $true }
} catch {}

if ($bucketExists) {
    Write-Ok "Bucket exists: $BucketName"
} elseif ($CheckOnly) {
    Write-Warn "Bucket does NOT exist: $BucketName (--CheckOnly mode, skipping creation)"
} else {
    Write-Info "Creating bucket: $BucketName"
    aws s3api create-bucket `
        --bucket $BucketName `
        --region $Region `
        --create-bucket-configuration LocationConstraint=$Region `
        --output text | Out-Null
    Write-Ok "Bucket created: $BucketName"
}

$versioning = aws s3api get-bucket-versioning `
    --bucket $BucketName `
    --query "Status" `
    --output text 2>$null
if ($versioning -eq "Enabled") {
    Write-Ok "Versioning: Enabled"
} elseif (-not $CheckOnly) {
    Write-Info "Enabling versioning"
    aws s3api put-bucket-versioning `
        --bucket $BucketName `
        --versioning-configuration Status=Enabled
    Write-Ok "Versioning enabled"
} else {
    Write-Warn "Versioning: NOT enabled"
}

$encryptionJson = aws s3api get-bucket-encryption --bucket $BucketName 2>$null
if ($encryptionJson -match "AES256") {
    Write-Ok "Encryption: AES256 (SSE-S3)"
} elseif (-not $CheckOnly) {
    Write-Info "Enabling AES256 encryption"
    $encConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-bucket-encryption `
        --bucket $BucketName `
        --server-side-encryption-configuration $encConfig
    Write-Ok "Encryption enabled"
} else {
    Write-Warn "Encryption: NOT configured"
}

$publicBlock = aws s3api get-public-access-block --bucket $BucketName 2>$null
if ($publicBlock -match '"BlockPublicAcls": true') {
    Write-Ok "Public access: Blocked"
} elseif (-not $CheckOnly) {
    Write-Info "Blocking all public access"
    $blockConfig = '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}'
    aws s3api put-public-access-block `
        --bucket $BucketName `
        --public-access-block-configuration $blockConfig
    Write-Ok "Public access blocked"
} else {
    Write-Warn "Public access: NOT blocked"
}

Write-Host ""
Write-Host "--- DynamoDB Table ---" -ForegroundColor Cyan

$tableStatus = aws dynamodb describe-table `
    --table-name $DynamoTable `
    --region $Region `
    --query "Table.TableStatus" `
    --output text 2>$null

if ($tableStatus -eq "ACTIVE") {
    Write-Ok "DynamoDB table exists and is ACTIVE: $DynamoTable"
} elseif ($tableStatus -eq "CREATING") {
    Write-Warn "DynamoDB table is still being created. Wait and re-run."
} elseif ($CheckOnly) {
    Write-Warn "DynamoDB table does NOT exist: $DynamoTable (--CheckOnly mode, skipping creation)"
} else {
    Write-Info "Creating DynamoDB table: $DynamoTable"
    aws dynamodb create-table `
        --table-name $DynamoTable `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region `
        --output text | Out-Null

    Write-Info "Waiting for table to become ACTIVE..."
    aws dynamodb wait table-exists --table-name $DynamoTable --region $Region
    Write-Ok "DynamoDB table created and ACTIVE: $DynamoTable"
}

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Cyan
Write-Host ""
Write-Host "  S3 Bucket      : s3://$BucketName" -ForegroundColor Green
Write-Host "  DynamoDB Table : $DynamoTable"      -ForegroundColor Green
Write-Host "  Region         : $Region"            -ForegroundColor Green
Write-Host ""
if (-not $CheckOnly) {
    Write-Ok "Remote state backend is ready. Run: terraform init"
} else {
    Write-Info "Check complete (read-only mode - no resources were created)."
}
Write-Host ""
