# Terraform AWS Template Automation Module

This Terraform module deploys the **EKS Terragrunt Repository Generator** — a Lambda-based solution that creates GitHub repositories pre-populated with rendered Terragrunt/HCL configuration for EKS cluster deployments. It is triggered via CloudFormation Custom Resources from AWS Service Catalog.

## Overview

This repository provides reusable Terraform modules for deploying and managing the Lambda function and related infrastructure that automate EKS cluster repository creation. It is part of a four-repository system:

## System Integration

This repository works together with the following:

1. **lambda-template-repo-generator**: The Lambda function code and Service Catalog product template that is deployed by this module.
2. **packer-pipeline**: Powers the CI/CD process by building the Lambda container images that this module deploys.
3. **template-eks-cluster**: The GitHub template repository used to seed new EKS cluster repos.

The modules in this repository are consumed by `lambda-template-repo-generator/deploy/` to provision all necessary AWS resources for the automation system.

## Features

- Serverless API endpoint via API Gateway
- Python-based Lambda function deployment (container image)
- CloudFormation Custom Resource integration for Service Catalog
- Secure IAM roles and permissions (Secrets Manager, SSM Parameter Store)
- VPC-capable Lambda for private GitHub Enterprise access
- Customizable resource naming via `name_prefix`
- EKS-specific: renders 8 Terragrunt/HCL files from Jinja2 templates

## Lambda Build Process with packer-pipeline

This module deploys the Lambda function as a container image that is built separately using the packer-pipeline tool. The packer-pipeline tool:

1. Creates or updates an AWS CodeBuild project
2. Uploads the Lambda function source code to S3
3. Executes a Packer build in CodeBuild
4. Pushes the resulting container image to Amazon ECR
5. Provides consistent build environments for every build

```hcl
module "eks_terragrunt_repo_generator" {
  source = "github.e.it.census.gov/SCT-Engineering/terraform-aws-template-automation"

  name_prefix = "eks-terragrunt-repo-gen"
  
  lambda_config = {
    image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/eks-terragrunt-repo-generator/lambda:latest"
  }
  
  # ... other configuration ...
}
```

For more information on building Lambda container images with packer-pipeline, see the [packer-pipeline repository](https://github.e.it.census.gov/SCT-Engineering/packer-pipeline).

## Usage

```hcl
module "eks_terragrunt_repo_generator" {
  source = "github.com/djaboxx/terraform-aws-template-automation"

  name_prefix = "eks-terragrunt-repo-gen"
  
  # GitHub Enterprise configuration
  github_api_url            = "https://github.e.it.census.gov"
  github_org_name           = "SCT-Engineering"
  template_repo_name        = "template-eks-cluster"
  template_config_file      = "config.json"
  github_commit_author_name = "Template Automation"
  github_commit_author_email = "automation@example.com"
  template_topics           = "infrastructure,eks,terragrunt"
  
  # GitHub token configuration
  github_token = {
    secret_name = "/eks-cluster-deployment/github_token"
  }
  
  # Lambda configuration using container image from ECR
  lambda_config = {
    image_uri    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/eks-terragrunt-repo-generator/lambda:latest"
    memory_size  = 512
    timeout      = 300

    vpc_config = {
      subnet_ids         = ["subnet-0b1992a84536c581b"]
      security_group_ids = ["sg-0641c697588b9aa6b"]
    }
  }
  
  # Parameter Store configuration 
  parameter_store_prefix = "/eks-terragrunt-repo-gen"

  tags = {
    Environment = "production"
    Project     = "eks-terragrunt-repo-generator"
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
| parameter_store_prefix | Prefix for SSM parameters | `string` | `/<name_prefix>` | no |
| ssm_parameters | Additional SSM parameters to create | `map(string)` | `{}` | no |
| github_api_url | URL for the GitHub Enterprise API | `string` | `https://api.github.com` | no |
| github_org_name | GitHub organization name | `string` | n/a | yes |
| template_repo_name | GitHub repository name for the template | `string` | n/a | yes |
| repo_visibility | Default visibility for newly created repos (`private`, `internal`, `public`) | `string` | `internal` | no |
| template_config_file | Name of the config file to write in new repositories | `string` | `config.json` | no |
| github_commit_author_name | Name for commit author | `string` | `Template Automation` | no |
| github_commit_author_email | Email for commit author | `string` | `automation@example.com` | no |
| template_topics | Topics to assign to new repositories (comma-separated string) | `string` | `infrastructure` | no |
| github_token | GitHub token configuration object with secret_name (required) and token (optional) | `object` | n/a | yes |
| lambda_config | Lambda function configuration object (image_uri, memory_size, timeout, vpc_config) | `object` | n/a | yes |
| log_retention_in_days | CloudWatch log retention in days | `number` | `14` | no |
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

## IAM Authentication

This module supports optional IAM authentication for the API Gateway endpoint. When enabled, clients must sign their requests using AWS SigV4 signing process.

### Enabling IAM Authentication

```hcl
module "template_automation" {
  source = "github.com/djaboxx/terraform-aws-template-automation"

  name_prefix = "my-automation"
  
  # Enable IAM authentication
  enable_iam_auth = true
  allowed_iam_arns = [
    "arn:aws:iam::123456789012:role/my-role",
    "arn:aws:iam::123456789012:user/my-user"
  ]

  # ... rest of your configuration ...
}
```

### Making Authenticated Requests

When IAM authentication is enabled, you'll need to sign your HTTP requests using AWS SigV4. Here are examples in different languages:

#### Python (using boto3)

```python
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

def invoke_api(url, payload):
    # Create a boto3 session (will use your default credentials)
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Prepare the request
    request = AWSRequest(
        method='POST',
        url=url,
        data=payload,
        headers={
            'Content-Type': 'application/json'
        }
    )
    
    # Sign the request
    SigV4Auth(credentials, 'execute-api', session.region_name).add_auth(request)
    
    # Send the request using the signed headers
    response = requests.post(
        url,
        headers=dict(request.headers),
        data=payload
    )
    return response

# Example usage
api_url = 'https://your-api-id.execute-api.region.amazonaws.com/prod/template'
payload = '{"templateName": "example"}'
response = invoke_api(api_url, payload)
```

#### AWS CLI

```bash
aws apigateway test-invoke-method \
  --rest-api-id your-api-id \
  --resource-id your-resource-id \
  --http-method POST \
  --path-with-query-string /template \
  --body '{"templateName": "example"}'
```

#### JavaScript (AWS SDK v3)

```javascript
import { SignatureV4 } from '@aws-sdk/signature-v4';
import { Sha256 } from '@aws-crypto/sha256-js';
import { defaultProvider } from '@aws-sdk/credential-provider-node';

async function invokeApi(url, payload) {
  // Create signature
  const signer = new SignatureV4({
    credentials: defaultProvider(),
    region: 'your-region',
    service: 'execute-api',
    sha256: Sha256
  });

  // Prepare request
  const request = new Request(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload)
  });

  // Sign request
  const signedRequest = await signer.sign(request);
  
  // Send request
  const response = await fetch(signedRequest);
  return response;
}

// Example usage
const apiUrl = 'https://your-api-id.execute-api.region.amazonaws.com/prod/template';
const payload = { templateName: 'example' };
const response = await invokeApi(apiUrl, payload);
```

### Required IAM Permissions

When IAM authentication is enabled, the calling identity needs the following IAM permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "execute-api:Invoke",
            "Resource": "arn:aws:execute-api:region:account-id:api-id/stage/POST/template"
        }
    ]
}
```

You can get the exact ARN from the module outputs:
```hcl
output "api_execution_arn" {
  value = module.template_automation.execution_arn
}
```

### Troubleshooting

Common issues when using IAM authentication:

1. **403 Forbidden**: Check that:
   - Your IAM role/user ARN is in the `allowed_iam_arns` list
   - You have the correct execute-api:Invoke permissions
   - Your request is properly signed with SigV4

2. **401 Unauthorized**: Verify that:
   - Your AWS credentials are valid and not expired
   - You're using the correct region in your signing process
   - The date/time in your request is accurate

3. **Missing Authentication Token**: Ensure that:
   - You're including all required SigV4 headers
   - The Authorization header is properly formatted

For more detailed troubleshooting, enable CloudWatch logs in the API Gateway stage settings.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
