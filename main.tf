# Get AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  lambda_function_name = "${var.name_prefix}-template-automation"
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
        Service = "lambda.amazonaws.com"
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
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_store_prefix}/*"
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
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.github_token.secret_name}-*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

resource "aws_api_gateway_rest_api" "template_automation" {
  name        = "${var.name_prefix}-template-automation"
  description = "API for template automation Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "template" {
  rest_api_id = aws_api_gateway_rest_api.template_automation.id
  parent_id   = aws_api_gateway_rest_api.template_automation.root_resource_id
  path_part   = "template"
}

resource "aws_api_gateway_method" "create_template" {
  rest_api_id   = aws_api_gateway_rest_api.template_automation.id
  resource_id   = aws_api_gateway_resource.template.id
  http_method   = "POST"
  authorization = var.enable_iam_auth ? "AWS_IAM" : "NONE"
}

# IAM Policy for API Gateway method access
data "aws_iam_policy_document" "api_gateway_invoke" {
  count = var.enable_iam_auth ? 1 : 0

  statement {
    effect = "Allow"
    actions = ["execute-api:Invoke"]

    resources = [
      "${aws_api_gateway_rest_api.template_automation.execution_arn}/*/${aws_api_gateway_method.create_template.http_method}${aws_api_gateway_resource.template.path}"
    ]

    principals {
      type        = "AWS"
      identifiers = var.allowed_iam_arns
    }
  }
}

# Resource policy for API Gateway when IAM auth is enabled
resource "aws_api_gateway_rest_api_policy" "template_automation" {
  count = var.enable_iam_auth ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.template_automation.id
  policy      = data.aws_iam_policy_document.api_gateway_invoke[0].json
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.template_automation.id
  resource_id = aws_api_gateway_resource.template.id
  http_method = aws_api_gateway_method.create_template.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.template_automation.invoke_arn
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.template_automation.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.template_automation.execution_arn}/*/*${aws_api_gateway_resource.template.path}"
}

# API Gateway deployment and stage
resource "aws_api_gateway_deployment" "template_automation" {
  rest_api_id = aws_api_gateway_rest_api.template_automation.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.template.id,
      aws_api_gateway_method.create_template.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.create_template,
    aws_api_gateway_integration.lambda_integration
  ]
}

resource "aws_api_gateway_stage" "template_automation" {
  deployment_id = aws_api_gateway_deployment.template_automation.id
  rest_api_id   = aws_api_gateway_rest_api.template_automation.id
  stage_name    = "prod"
}
