param(
    [Parameter(Mandatory)]
    [ValidateSet("apply", "destroy")]
    [string]$Mode
)

$Region      = "ap-south-1"
$ClusterName = "gitops-cluster"

function Write-Info    ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok      ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err     ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Step    ($msg) { Write-Host "`n--- $msg ---" -ForegroundColor Magenta }

# Ensure we are running from the terraform directory (parent of this script's directory)
$TfDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location -Path $TfDir
Write-Info "Working directory set to: $TfDir"



function Unlock-StateIfLocked {
    $output = terraform plan 2>&1 | Out-String
    if ($output -match "ID:\s+([a-f0-9\-]{36})") {
        $lockId = $matches[1]
        Write-Warn "State is locked (ID: $lockId). Force-unlocking..."
        terraform force-unlock -force $lockId
        Write-Ok "State unlocked."
    }
}

function Remove-OrphanedNodeGroups {
    Write-Info "Checking for orphaned node groups on cluster: $ClusterName"
    $groups = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --query "nodegroups" --output json 2>$null | ConvertFrom-Json
    if (-not $groups -or $groups.Count -eq 0) {
        Write-Ok "No orphaned node groups found."
        return
    }
    foreach ($ng in $groups) {
        Write-Warn "Found orphaned node group: $ng. Deleting..."
        aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $ng --region $Region --output text | Out-Null
        Write-Info "Waiting for node group '$ng' to be deleted (this may take 5-10 min)..."
        aws eks wait nodegroup-deleted --cluster-name $ClusterName --nodegroup-name $ng --region $Region
        Write-Ok "Node group '$ng' deleted."
    }
}

function Show-Outputs {
    Write-Step "Outputs"
    $endpoint  = terraform output -raw cluster_endpoint 2>$null
    $name      = terraform output -raw cluster_name 2>$null
    $kubecmd   = terraform output -raw kubeconfig_command 2>$null
    $argoNs    = terraform output -raw argocd_namespace 2>$null

    if ($name) {
        Write-Host ""
        Write-Host "  Cluster Name    : $name"     -ForegroundColor Green
        Write-Host "  Cluster Endpoint: $endpoint"  -ForegroundColor Green
        Write-Host "  ArgoCD Namespace: $argoNs"    -ForegroundColor Green
        Write-Host ""
        Write-Host "  Connect kubectl :" -ForegroundColor Cyan
        Write-Host "    $kubecmd"
        Write-Host ""
        Write-Host "  ArgoCD URL (after LB provision):" -ForegroundColor Cyan
        Write-Host "    kubectl get svc -n argocd argocd-server"
        Write-Host ""
        Write-Host "  ArgoCD Password:" -ForegroundColor Cyan
        Write-Host '    $p = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"'
        Write-Host '    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($p))'
        Write-Host ""
    }
}

function Remove-OrphanedLoadBalancers {
    Write-Info "Checking for orphaned Load Balancers in cluster VPC..."
    $vpcId = aws ec2 describe-vpcs --filters "Name=tag:kubernetes.io/cluster/$ClusterName,Values=shared" --query "Vpcs[0].VpcId" --output text 2>$null
    
    if (-not $vpcId -or $vpcId -eq "None") {
        Write-Info "VPC for cluster $ClusterName not found. Skipping ELB cleanup."
        return
    }
    
    Write-Info "Found VPC: $vpcId"
    
    $classicElbs = aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId==`'$vpcId`'].LoadBalancerName" --output json 2>$null | ConvertFrom-Json
    if ($classicElbs) {
        foreach ($elb in $classicElbs) {
            Write-Warn "Deleting Classic ELB: $elb"
            aws elb delete-load-balancer --load-balancer-name $elb
        }
    }
    
    $elbv2s = aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId==`'$vpcId`'].LoadBalancerArn" --output json 2>$null | ConvertFrom-Json
    if ($elbv2s) {
        foreach ($elb in $elbv2s) {
            Write-Warn "Deleting ELBv2: $elb"
            aws elbv2 delete-load-balancer --load-balancer-arn $elb
        }
    }
    
    if ($classicElbs -or $elbv2s) {
        Write-Info "Waiting 30 seconds for ENIs to be detached..."
        Start-Sleep -Seconds 30
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Terraform GitOps Manager  [mode: $Mode]" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Unlock-StateIfLocked

if ($Mode -eq "apply") {

    Write-Step "Phase 1: VPC + EKS (K8s 1.36)"
    terraform apply -target module.vpc -target module.eks -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Phase 1 failed. Check errors above."
        exit 1
    }
    Write-Ok "Phase 1 complete."

    Write-Step "Phase 2: ArgoCD Helm Release"
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Phase 2 failed. Check errors above."
        exit 1
    }
    Write-Ok "Phase 2 complete. Full stack deployed."

    Show-Outputs

} elseif ($Mode -eq "destroy") {

    Write-Step "Pre-destroy: Cleaning orphaned resources"
    $clusterExists = aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.name" --output text 2>$null
    if ($clusterExists -eq $ClusterName) {
        Remove-OrphanedNodeGroups
    } else {
        Write-Info "Cluster '$ClusterName' not found in AWS. Skipping node group cleanup."
    }
    
    Remove-OrphanedLoadBalancers

    Write-Step "Destroying all resources"
    terraform destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Destroy failed. Check errors above."
        exit 1
    }

    Write-Ok "All resources destroyed successfully."
    Write-Host ""
}
