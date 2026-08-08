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
