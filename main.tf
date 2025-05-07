# Get AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  lambda_function_name = "${var.name_prefix}-template-automation"

  # Sample payload for Lambda testing - template based on the actual template repository
  eks_settings = {
    attrs = {
      account_name           = "dev-account"
      aws_region             = data.aws_region.current.name
      cluster_mailing_list   = "eks-admins@example.com"
      cluster_name           = "example-cluster-dev"
      eks_instance_disk_size = 100
      eks_ng_desired_size    = 2
      eks_ng_max_size        = 10
      eks_ng_min_size        = 2
      environment            = "development"
      environment_abbr       = "dev"
      organization           = "example:dept:team"
      finops_project_name    = "example_project"
      finops_project_number  = "fp00000001"
      finops_project_role    = "example_project_app"
      vpc_domain_name        = "dev.example.com"
      vpc_name               = "vpc-dev"
    }
    tags = {
      "slim:schedule" = "8:00-17:00"
      managed_by      = "terraform"
      owner           = "platform-team"
    }
  }

  generic_settings = {
    attrs = {
      account_name = "dev-account"
      aws_region   = data.aws_region.current.name
      environment  = "development"
    }
    tags = {
      managed_by = "terraform"
      owner      = "platform-team"
    }
  }

  sample_payload = {
    project_name          = "example-${var.name_prefix}-cluster"
    template_settings     = var.template_repo_name == "template-eks-cluster" ? local.eks_settings : local.generic_settings
    trigger_init_workflow = true
    owning_team           = "platform-team"
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

  name  = "${var.parameter_store_prefix}/${each.key}"
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

  environment {
    variables = merge(
      var.lambda_config.environment_variables,
      {
        PARAM_STORE_PREFIX       = var.parameter_store_prefix
        GITHUB_TOKEN_SECRET_NAME = var.github_token.secret_name
      }
    )
  }

  tags = var.tags
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
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_store_prefix}/*"
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

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Secrets Manager secret for GitHub token
resource "aws_secretsmanager_secret" "github_token" {
  count = var.github_token.token != null ? 1 : 0
  name  = var.github_token.secret_name
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  count         = var.github_token.token != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.github_token[0].id
  secret_string = var.github_token.token
}


