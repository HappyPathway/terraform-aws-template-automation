# Default variable values for terraform-aws-template-automation
# Copy this file and adjust values for your environment.

name_prefix = "eks-terragrunt-repo-gen"

# GitHub Enterprise configuration
github_api_url             = "https://github.e.it.census.gov"
github_org_name            = "SCT-Engineering"
template_repo_name         = "template-eks-cluster"
template_config_file       = "config.json"
github_commit_author_name  = "Template Automation"
github_commit_author_email = "automation@census.gov"
template_topics            = "infrastructure,eks,terragrunt"
# GHE enterprise policy blocks 'private' repo creation for org members; use 'internal'
repo_visibility = "internal"

# Lambda configuration
lambda_config = {
  image_uri   = "229685449397.dkr.ecr.us-gov-west-1.amazonaws.com/eks-terragrunt-repo-generator/lambda:latest"
  memory_size = 512
  timeout     = 300
  environment_variables = {
    VERIFY_SSL = "true"
  }
}

# GitHub token (secret must already exist in Secrets Manager, or provide token to create it)
github_token = {
  secret_name = "/eks-cluster-deployment/github_token"
}

# CloudWatch log retention
log_retention_in_days = 14

# SSM parameter store prefix
parameter_store_prefix = "/template-automation"

tags = {
  Environment = "production"
  Project     = "template-automation"
  ManagedBy   = "terraform"
}
