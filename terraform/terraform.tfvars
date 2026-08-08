aws_region           = "ap-south-1"
cluster_name         = "gitops-cluster"
node_instance_type   = "c7i-flex.large"
node_desired_size    = 1
node_min_size        = 1
node_max_size        = 2
argocd_namespace     = "argocd"
argocd_chart_version = "7.4.3"
