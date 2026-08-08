terraform {
  backend "s3" {
    bucket         = "gitops-tfstate-ap-south-1"
    key            = "gitops/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "gitops-tf-lock"
    encrypt        = true
  }
}
