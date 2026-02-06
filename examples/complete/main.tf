provider "aws" {
  region = "us-east-1"
}

module "template_automation" {
  source = "../.."

  name_prefix = "my-org"

  # GitHub configuration
  github_api_url             = "https://github.example.com/api/v3"
  github_org_name            = "my-org"
  template_repo_name         = "my-template-repo"
  template_config_file       = "config.json"
  github_commit_author_name  = "Template Automation"
  github_commit_author_email = "automation@example.com"
  template_topics            = "infrastructure,template"

  # Lambda configuration (container image from ECR)
  lambda_config = {
    image_uri   = "229685449397.dkr.ecr.us-gov-west-1.amazonaws.com/template-automation-lambda:latest"
    memory_size = 512
    timeout     = 300

    environment_variables = {
      VERIFY_SSL = "true"
    }

    # Optional: deploy Lambda inside a VPC for private GitHub Enterprise access
    # vpc_config = {
    #   subnet_ids         = ["subnet-abc123", "subnet-def456"]
    #   security_group_ids = ["sg-abc123"]
    # }
  }

  # GitHub token stored in Secrets Manager
  github_token = {
    secret_name = "template-automation/github-token"
    # Optionally create the secret with Terraform (not recommended for production):
    # token      = var.github_token
    # kms_key_id = aws_kms_key.example.arn
  }

  # CloudWatch log retention
  log_retention_in_days = 14

  # SSM Parameter Store prefix
  parameter_store_prefix = "/template-automation"

  # Additional custom SSM parameters
  ssm_parameters = {
    "CUSTOM_PARAM" = "custom-value"
  }

  tags = {
    Environment = "production"
    Project     = "template-automation"
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
#     MyRepository:
#       Type: Custom::RepositoryCreator
#       Properties:
#         ServiceToken: <module.template_automation.cloudformation_service_token>
#         ProjectName: my-new-repo
#         OwningTeam: platform-team
#         Environment: development
# --------------------------------------------------------------------------

output "lambda_arn" {
  description = "Lambda ARN for use as CloudFormation ServiceToken"
  value       = module.template_automation.cloudformation_service_token
}

output "api_endpoint" {
  description = "API Gateway endpoint (alternative invocation method)"
  value       = module.template_automation.api_endpoint
}

output "log_group" {
  description = "CloudWatch Log Group for debugging"
  value       = module.template_automation.cloudwatch_log_group_name
}
