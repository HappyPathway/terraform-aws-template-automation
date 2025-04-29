output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "api_endpoint" {
  description = "The URL of the API Gateway endpoint"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "template_automation_url" {
  description = "The full URL to call for template automation"
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/template"
}

output "lambda_role_arn" {
  description = "The ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.lambda.arn
}
