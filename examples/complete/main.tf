provider "aws" {
  region = "us-gov-west-1"
}

module "eks_terragrunt_repo_generator" {
  source = "../.."

  name_prefix = "eks-terragrunt-repo-gen"

  # GitHub Enterprise configuration
  github_api_url             = "https://github.e.it.census.gov"
  github_org_name            = "SCT-Engineering"
  template_repo_name         = "template-eks-cluster"
  template_config_file       = "config.json"
  github_commit_author_name  = "Template Automation"
  github_commit_author_email = "automation@example.com"
  template_topics            = "infrastructure,eks,terragrunt"

  # Lambda configuration (container image from ECR)
  lambda_config = {
    image_uri   = "229685449397.dkr.ecr.us-gov-west-1.amazonaws.com/eks-terragrunt-repo-generator/lambda:latest"
    memory_size = 512
    timeout     = 300

    environment_variables = {
      VERIFY_SSL = "true"
    }

    # Deploy Lambda inside a VPC for private GitHub Enterprise access
    vpc_config = {
      subnet_ids         = ["subnet-0b1992a84536c581b"]
      security_group_ids = ["sg-0641c697588b9aa6b"]
    }
  }

  # GitHub token stored in Secrets Manager
  github_token = {
    secret_name = "/eks-cluster-deployment/github_token"
    # Optionally create the secret with Terraform (not recommended for production):
    # token      = var.github_token
    # kms_key_id = aws_kms_key.example.arn
  }

  # CloudWatch log retention
  log_retention_in_days = 14

  # SSM Parameter Store prefix
  parameter_store_prefix = "/eks-terragrunt-repo-gen"

  # Additional custom SSM parameters
  ssm_parameters = {
    "CUSTOM_PARAM" = "custom-value"
  }

  tags = {
    Environment = "production"
    Project     = "eks-terragrunt-repo-generator"
    ManagedBy   = "terraform"
  }
}

# --------------------------------------------------------------------------
# Use the Lambda as a CloudFormation Custom Resource ServiceToken
# --------------------------------------------------------------------------
# In your CloudFormation templates (or Service Catalog products), reference
# the Lambda ARN as the ServiceToken:
#
#   Resources:
#     EKSClusterRepo:
#       Type: Custom::GitHubRepository
#       Properties:
#         ServiceToken: <module.eks_terragrunt_repo_generator.cloudformation_service_token>
#         project_name: my-eks-cluster
#         owning_team: platform-team
#         cluster_name: my-eks-cluster
#         environment: dev
#         aws_region: us-gov-west-1
#         account_name: csvd-dev-ew
#         aws_account_id: "123456789012"
#         environment_abbr: dev
#         vpc_name: csvd-dev-ew-vpc-01
#         vpc_domain_name: dev.inf.csp1.census.gov
# --------------------------------------------------------------------------

output "lambda_arn" {
  description = "Lambda ARN for use as CloudFormation ServiceToken"
  value       = module.eks_terragrunt_repo_generator.cloudformation_service_token
}

output "api_endpoint" {
  description = "API Gateway endpoint (alternative invocation method)"
  value       = module.eks_terragrunt_repo_generator.api_endpoint
}

output "log_group" {
  description = "CloudWatch Log Group for debugging"
  value       = module.eks_terragrunt_repo_generator.cloudwatch_log_group_name
}
