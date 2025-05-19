# Terraform AWS Template Automation Module

This Terraform module deploys a template automation solution using AWS Lambda and API Gateway. It provides a serverless architecture for automating template creation and management.

## Overview

This repository provides reusable Terraform modules for deploying and managing the Lambda function and related infrastructure that automate repository creation and configuration. It is part of a four-repository system for infrastructure automation.

## System Integration

This repository works together with the following:

1. **template-repos-lambda-deployment**: Uses these modules to deploy the Lambda function and manage AWS resources.
2. **template-automation-lambda**: The Lambda function code that is deployed and managed by these modules.

The modules in this repository are consumed by the deployment repository to provision all necessary AWS resources for the automation system.

## Features

- Serverless API endpoint via API Gateway
- Python-based Lambda function deployment
- Secure IAM roles and permissions
- Configurable environment variables
- CORS configuration for API Gateway
- Customizable resource naming via prefix

## Lambda Build Process

This module deploys the template automation Lambda function, which is built separately in the template-automation-lambda repository using a Packer configuration file. The build process runs in GitHub Actions, creating the deployment package that this module uses.

While this module handles the deployment of the Lambda function to AWS, it relies on the pre-built Lambda package created through the Packer-based build pipeline.

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
    
    # Option 2: Use S3-hosted deployment package (recommended for Packer-built Lambda)
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
