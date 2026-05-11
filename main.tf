# Get AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_organizations_organization" "current" {}

# CloudWatch Log Group for Lambda (managed, with retention)
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

locals {
  lambda_function_name   = "${var.name_prefix}-template-automation"
  parameter_store_prefix = var.parameter_store_prefix != null ? var.parameter_store_prefix : "/${var.name_prefix}"

  sample_payload = {
    RequestType       = "Create"
    ResponseURL       = "https://cloudformation-custom-resource-response-useast1.s3.amazonaws.com/example"
    StackId           = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/example-stack/example-id"
    RequestId         = "example-request-id"
    ResourceType      = "Custom::GitHubRepository"
    LogicalResourceId = "EKSClusterRepository"
    ResourceProperties = {
      ServiceToken     = aws_lambda_function.this.arn
      project_name     = "example-${var.name_prefix}-repo"
      owning_team      = "platform-team"
      cluster_name     = "example-${var.name_prefix}-cluster"
      environment      = "dev"
      aws_region       = data.aws_region.current.name
      account_name     = "csvd-dev-ew"
      aws_account_id   = data.aws_caller_identity.current.account_id
      environment_abbr = "dev"
      vpc_name         = "csvd-dev-ew-vpc-01"
      vpc_domain_name  = "dev.inf.csp1.census.gov"
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for template automation Lambda function"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  tags = var.tags
}

# SSM Parameters
resource "aws_ssm_parameter" "parameters" {
  for_each = merge(
    var.ssm_parameters,
    {
      "GITHUB_API"                 = var.github_api_url
      "GITHUB_ORG_NAME"            = var.github_org_name
      "TEMPLATE_REPO_NAME"         = var.template_repo_name
      "TEMPLATE_CONFIG_FILE"       = var.template_config_file
      "GITHUB_COMMIT_AUTHOR_NAME"  = var.github_commit_author_name
      "GITHUB_COMMIT_AUTHOR_EMAIL" = var.github_commit_author_email
      "TEMPLATE_TOPICS"            = var.template_topics
    }
  )

  name  = "${local.parameter_store_prefix}/${each.key}"
  type  = "String"
  value = each.value
  tags  = var.tags
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda.arn
  timeout       = var.lambda_config.timeout
  memory_size   = var.lambda_config.memory_size
  publish       = true

  package_type = "Image"
  image_uri    = var.lambda_config.image_uri

  dynamic "image_config" {
    for_each = var.lambda_config.image_config != null ? [var.lambda_config.image_config] : []
    content {
      command           = image_config.value.command
      entry_point       = image_config.value.entry_point
      working_directory = image_config.value.working_directory
    }
  }

  dynamic "vpc_config" {
    for_each = var.lambda_config.vpc_config != null ? [var.lambda_config.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  environment {
    variables = merge(
      var.lambda_config.environment_variables,
      {
        PARAM_STORE_PREFIX       = local.parameter_store_prefix
        GITHUB_TOKEN_SECRET_NAME = var.github_token.secret_name
        GITHUB_API               = var.github_api_url
        GITHUB_ORG_NAME          = var.github_org_name
        TEMPLATE_REPO_NAME       = var.template_repo_name
        REPO_VISIBILITY          = var.repo_visibility
      }
    )
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_logs,
  ]
}

# Lambda permission for CloudFormation Custom Resource invocation
# Uses principal_org_id so CloudFormation in any account within the home AWS
# Organization can invoke the Lambda cross-account (Service Catalog org-wide sharing).
resource "aws_lambda_permission" "cloudformation" {
  statement_id     = "AllowCloudFormationInvokeOrgWide"
  action           = "lambda:InvokeFunction"
  function_name    = aws_lambda_function.this.function_name
  principal        = "cloudformation.amazonaws.com"
  principal_org_id = data.aws_organizations_organization.current.id
}

# Lambda permissions for accounts that live outside the home AWS Organization.
#
# Service Catalog invokes Lambda Custom Resources using the SC launch role's
# assumed-role identity, not cloudformation.amazonaws.com. The Lambda resource
# policy must therefore grant the specific IAM launch role ARN from each account.
#
# NOTE: GovCloud Lambda add-permission rejects these calls if the policy already
# contains any raw AWS-principal statement (role/user ARN or ID). Remove any
# such manually-added statements before applying (the blocker was the legacy
# AllowLabLaunchRole statement with a raw role ID).
locals {
  trusted_account_launch_role_arns = {
    for name, cfg in var.trusted_aws_accounts :
    name => "arn:${data.aws_partition.current.partition}:iam::${cfg.account_id}:role/${cfg.launch_role_name}"
    if try(cfg.launch_role_name, "") != ""
  }
}

resource "aws_lambda_permission" "cloudformation_trusted_account" {
  for_each = local.trusted_account_launch_role_arns

  statement_id  = "AllowCloudFormationInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = each.value
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /template"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*/template"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.${data.aws_partition.current.dns_suffix}"
      }
    }]
  })

  tags = var.tags
}

# IAM policy for Parameter Store access
resource "aws_iam_role_policy" "parameter_store" {
  name = "${var.name_prefix}-parameter-store-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_store_prefix}/*"
        ]
      }
    ]
  })
}

# IAM policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_manager" {
  name = "${var.name_prefix}-secrets-manager-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.github_token.secret_name}-*"
        ]
      }
    ]
  })
}

# IAM policy for KMS access
resource "aws_iam_role_policy" "kms_access" {
  name = "${var.name_prefix}-kms-access-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.github_token.kms_key_id != null ? var.github_token.kms_key_id : "*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy for Lambda
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Secrets Manager secret for GitHub token
resource "aws_secretsmanager_secret" "github_token" {
  count      = var.github_token.token != null ? 1 : 0
  name       = var.github_token.secret_name
  kms_key_id = var.github_token.kms_key_id
  tags       = var.tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  count         = var.github_token.token != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.github_token[0].id
  secret_string = var.github_token.token
}


