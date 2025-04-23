# Get AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  lambda_function_name = "${var.name_prefix}-template-automation"
  use_s3_source = var.lambda_config.s3 != null
  use_local_archive = var.lambda_config.create_zipfile
}

# Create zip file from source code if enabled
data "archive_file" "lambda" {
  count       = local.use_local_archive ? 1 : 0
  type        = "zip"
  source_dir  = var.lambda_config.source_path
  output_path = "${path.module}/lambda.zip"
  excludes    = ["__pycache__", "*.pyc"]
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
  for_each = var.ssm_parameters

  name  = "${var.parameter_store_prefix}/${each.key}"
  type  = "String"
  value = each.value
  tags  = var.tags
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name = local.lambda_function_name
  role         = aws_iam_role.lambda.arn
  handler      = "app.lambda_handler"
  runtime      = var.lambda_config.runtime
  timeout      = var.lambda_config.timeout
  memory_size  = var.lambda_config.memory_size

  # Source configuration - only one of these will be set
  dynamic "filename" {
    for_each = var.lambda_config.create_zipfile || var.lambda_config.zip_path != null ? [1] : []
    content {
      filename = var.lambda_config.create_zipfile ? data.archive_file.lambda[0].output_path : var.lambda_config.zip_path
    }
  }

  dynamic "s3" {
    for_each = var.lambda_config.s3 != null ? [var.lambda_config.s3] : []
    content {
      bucket         = s3.value.bucket
      key            = s3.value.key
      object_version = try(s3.value.object_version, null)
    }
  }

  environment {
    variables = merge(
      var.lambda_config.environment_variables,
      {
        PARAM_STORE_PREFIX = var.parameter_store_prefix
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

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
