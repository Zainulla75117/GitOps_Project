# GitOps AWS Kubernetes Demo

A complete end-to-end GitOps workflow deploying a modern web application (React + FastAPI) to Amazon EKS. 

This repository demonstrates Infrastructure as Code (IaC) and a fully automated Continuous Delivery (CD) loop using GitHub Actions and ArgoCD.

## Architecture

- **Infrastructure**: AWS EKS, VPC, and ECR provisioned via **Terraform**.
- **Backend**: **FastAPI** (Python) REST API.
- **Frontend**: **React** (Vite) single-page application.
- **CI/CD Pipeline**: 
  - **GitHub Actions** builds Docker images and pushes them to AWS ECR via OIDC authentication.
  - Automatically commits new image tags back to the Helm chart in this repository.
- **GitOps**: **ArgoCD** continuously monitors the Helm chart and automatically syncs the EKS cluster state to match the Git repository.

## Workflow

1. A developer pushes code changes to `main`.
2. GitHub Actions runs, builds the new Docker images, and pushes them to AWS ECR.
3. GitHub Actions automatically updates `helm/gitops-app/values.yaml` with the new image tag and commits it.
4. ArgoCD detects the configuration change in Git and automatically rolls out the new pods to the EKS cluster without manual intervention.

---

## Getting Started

### Prerequisites

To provision this infrastructure and deploy the application from scratch, you will need the following tools installed locally:

- [AWS CLI](https://aws.amazon.com/cli/) (configured with administrator credentials)
- [Terraform](https://www.terraform.io/downloads) (v1.5.0+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- PowerShell (Windows) or Bash (macOS/Linux)
- [Git](https://git-scm.com/)

### 1. Bootstrap Terraform State

Terraform requires a remote backend to store its state file securely. We have provided a script to automatically create an AWS S3 Bucket and a DynamoDB table for state locking.

Run the bootstrap script from the `terraform` directory:
```bash
cd terraform
bash scripts/bootstrap-state.sh
```

### 2. Provision Infrastructure

We have provided a streamlined PowerShell manager script (`tf-manager.ps1`) to handle the entire cluster lifecycle. This script applies Terraform, updates your local `kubeconfig`, and retrieves the initial ArgoCD admin password.

To provision the VPC, EKS Cluster, ECR repositories, and install ArgoCD:
```powershell
cd terraform
.\scripts\tf-manager.ps1 apply
```

*Note: The cluster provisioning process takes approximately 15-20 minutes.*

### 3. Deploy the Application

Once the cluster is up and ArgoCD is running, apply the ArgoCD Application manifest from the root of the repository to start the GitOps sync:

```powershell
kubectl apply -f argocd-app.yaml
```

ArgoCD will immediately detect the Helm chart in the `helm/gitops-app` directory and begin deploying the FastAPI backend and React frontend to the cluster.

### 4. Access the UI

To get the external URL for the frontend application:
```powershell
kubectl get svc -n gitops-app gitops-app-frontend
```
Copy the `EXTERNAL-IP` load balancer URL and paste it into your browser.

### Teardown

To destroy the cluster and all associated AWS resources to avoid incurring further charges:
```powershell
cd terraform
.\scripts\tf-manager.ps1 destroy
```
