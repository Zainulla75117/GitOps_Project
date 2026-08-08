# GitOps Infrastructure — Terraform

## Prerequisites

| Tool | Minimum Version |
|---|---|
| Terraform | >= 1.6.0 |
| AWS CLI | >= 2.x |
| kubectl | >= 1.30 |
| Helm | >= 3.x |

Ensure your AWS CLI is configured with credentials that have permissions to create VPC, EKS, EC2, IAM, and ELB resources.

```bash
aws configure
```

---

## Step 1 — Bootstrap Remote State (One-Time Only)

The S3 bucket and DynamoDB table must exist before running `terraform init`. Run these commands once:

```bash
aws s3api create-bucket \
  --bucket gitops-tfstate-ap-south-1 \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket gitops-tfstate-ap-south-1 \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket gitops-tfstate-ap-south-1 \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name gitops-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

---

## Step 2 — Initialize Terraform

```bash
cd terraform
terraform init
```

---

## Step 3 — Apply in Two Phases

Because the Helm and Kubernetes providers authenticate against the EKS cluster at runtime, the cluster must exist before ArgoCD can be deployed.

**Phase 1 — Provision VPC + EKS:**

```bash
terraform apply -target=module.vpc -target=module.eks
```

This takes approximately **12–18 minutes** to complete.

**Phase 2 — Deploy ArgoCD:**

```bash
terraform apply
```

---

## Step 4 — Connect kubectl to the Cluster

```bash
aws eks update-kubeconfig --name gitops-cluster --region ap-south-1
```

Verify the node is ready:

```bash
kubectl get nodes
```

Expected output:

```
NAME                                        STATUS   ROLES    AGE   VERSION
ip-10-0-x-x.ap-south-1.compute.internal    Ready    <none>   5m    v1.30.x
```

---

## Step 5 — Access ArgoCD UI

Get the LoadBalancer hostname:

```bash
kubectl get svc -n argocd argocd-server
```

Open the `EXTERNAL-IP` value in your browser on port 80.

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

Login credentials:
- **Username:** `admin`
- **Password:** output from the command above

---

## Tear Down

```bash
terraform destroy
```

After destroy, optionally delete the remote state resources:

```bash
aws s3 rb s3://gitops-tfstate-ap-south-1 --force
aws dynamodb delete-table --table-name gitops-tf-lock --region ap-south-1
```

---

## Architecture

```
ap-south-1
│
├── S3: gitops-tfstate-ap-south-1     (Terraform state)
├── DynamoDB: gitops-tf-lock          (State locking)
│
└── VPC: gitops-cluster-vpc (10.0.0.0/16)
    ├── Public Subnets  [ap-south-1a, ap-south-1b]  — NAT, ELB
    └── Private Subnets [ap-south-1a, ap-south-1b]
        └── EKS: gitops-cluster (K8s 1.30)
            ├── Control Plane  (AWS managed)
            └── Node Group: 1x t3.medium
                └── ArgoCD (Helm 7.4.3, exposed via LoadBalancer)
```

---

## File Structure

```
terraform/
├── versions.tf
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eks/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── argocd/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```
