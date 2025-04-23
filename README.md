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

  name_prefix          = "my-automation"
  create_lambda_zipfile = true
  lambda_source_path   = "../template_automation"  # Path to your Lambda source code
  
  # Parameter Store configuration
  parameter_store_prefix = "/template-automation"
  ssm_parameters = {
    "TEMPLATE_REPO_NAME"         = "my-template-repo"
    "GITHUB_API"                 = "https://api.github.com"
    "GITHUB_ORG_NAME"           = "my-org"
    "TEMPLATE_CONFIG_FILE"       = "config.json"
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
| create_lambda_zipfile | Whether to create the Lambda zip file from source code | `bool` | `false` | no |
| lambda_source_path | Path to the Lambda function source code directory | `string` | `null` | yes, if create_lambda_zipfile is true |
| lambda_zip_path | Path to pre-built Lambda deployment package | `string` | n/a | yes, if neither create_lambda_zipfile nor lambda_s3_source is true |
| lambda_s3_source | Whether to source the Lambda zip from S3 | `bool` | `false` | no |
| lambda_s3_bucket | S3 bucket containing the Lambda zip file | `string` | `null` | yes, if lambda_s3_source is true |
| lambda_s3_key | S3 key of the Lambda zip file | `string` | `null` | yes, if lambda_s3_source is true |
| lambda_s3_object_version | S3 object version of the Lambda zip file | `string` | `null` | no |
| lambda_runtime | Runtime for the Lambda function | `string` | `"python3.9"` | no |
| lambda_timeout | Timeout for the Lambda function in seconds | `number` | `300` | no |
| lambda_memory_size | Memory size for the Lambda function in MB | `number` | `256` | no |
| environment_variables | Environment variables for the Lambda function | `map(string)` | `{}` | no |
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
