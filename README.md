# Terraform AWS Template Automation Module

This Terraform module deploys a template automation solution using AWS Lambda and API Gateway. It provides a serverless architecture for automating template creation and management.

## Features

- Serverless API endpoint via API Gateway
- Python-based Lambda function deployment
- Secure IAM roles and permissions
- Configurable environment variables
- CORS configuration for API Gateway
- Customizable resource naming via prefix

## Usage

```hcl
module "template_automation" {
  source = "github.com/djaboxx/terraform-aws-template-automation"

  name_prefix = "my-automation"
  
  # GitHub configuration
  github_api_url            = "https://api.github.com"
  github_org_name           = "my-org"
  template_repo_name        = "my-template-repo"
  template_config_file      = "config.json"
  github_commit_author_name = "Template Automation"
  github_commit_author_email = "automation@example.com"
  template_topics           = "infrastructure,template"
  
  # GitHub token configuration
  github_token = {
    secret_name = "github/token"
    # token     = "your-token-here"  # Optional: Provide directly (not recommended for production)
  }
  
  # Lambda configuration
  lambda_config = {
    create_zipfile = true
    source_path    = "../template_automation"  # Path to your Lambda source code
    runtime        = "python3.9"
    memory_size    = 256
    timeout        = 300
    
    # Alternative options for deployment package:
    # Option 1: Use pre-built zip file
    # create_zipfile = false
    # zip_path      = "path/to/function.zip"
    
    # Option 2: Use S3-hosted deployment package
    # create_zipfile = false
    # s3 = {
    #   bucket         = "my-lambda-bucket"
    #   key            = "lambda/template-automation.zip"
    #   object_version = "1" # optional
    # }
  }
  
  # Parameter Store configuration 
  parameter_store_prefix = "/template-automation"
  # Additional custom parameters if needed
  ssm_parameters = {
    "ADDITIONAL_PARAM" = "custom-value"
  }

  environment_variables = {
    SECRET_NAME = "github/token"  # AWS Secrets Manager secret containing GitHub token
  }

  tags = {
    Environment = "production"
    Project     = "template-automation"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix to be used for resource names | `string` | n/a | yes |
| parameter_store_prefix | Prefix for SSM parameters | `string` | `/template-automation` | no |
| ssm_parameters | Additional SSM parameters to create | `map(string)` | `{}` | no |
| github_api_url | URL for the GitHub Enterprise API | `string` | `https://api.github.com` | no |
| github_org_name | GitHub organization name | `string` | n/a | yes |
| template_repo_name | GitHub repository name for the template | `string` | n/a | yes |
| template_config_file | Name of the config file to write in new repositories | `string` | `config.json` | no |
| github_commit_author_name | Name for commit author | `string` | `Template Automation` | no |
| github_commit_author_email | Email for commit author | `string` | `automation@example.com` | no |
| template_topics | Topics to assign to new repositories (comma-separated string) | `string` | `infrastructure` | no |
| github_token | GitHub token configuration object with secret_name (required) and token (optional) | `object` | n/a | yes |
| lambda_config | Lambda function configuration object | `object` | n/a | yes |
| tags | Tags to be applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | The ARN of the Lambda function |
| lambda_function_name | The name of the Lambda function |
| api_endpoint | The URL of the API Gateway endpoint |
| api_id | The ID of the API Gateway |
| lambda_role_arn | The ARN of the IAM role used by the Lambda function |

## Architecture

This module creates:
1. An HTTP API Gateway endpoint
2. A Lambda function to handle requests
3. Necessary IAM roles and permissions
4. API Gateway integration with the Lambda function
5. CORS configuration for the API endpoint

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
