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
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/template"
}

output "api_id" {
  description = "The ID of the API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "lambda_role_arn" {
  description = "The ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_id" {
  description = "The ID of the Lambda execution role"
  value       = aws_iam_role.lambda.id
}

output "api_execution_arn" {
  description = "The execution ARN to be used in IAM policies"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "sample_payload" {
  description = "A sample payload that can be used to test the Lambda function in the AWS Console"
  value       = local.sample_payload
}

output "test_function_instructions" {
  description = "Instructions for testing the Lambda function in the AWS Console"
  value       = <<-EOT
    To test the Lambda function in the AWS Console:
    
    1. Go to the AWS Lambda console
    2. Select the function: ${aws_lambda_function.this.function_name}
    3. Click on the "Test" tab
    4. Create a new test event with any name
    5. Copy and paste the json_payload output from Terraform (not sample_payload)
    6. Click "Test" to execute the function
    
    The Lambda will create a new repository and pull request based on the template.
  EOT
}

output "json_payload" {
  description = "A JSON-formatted payload string that can be directly copied into the AWS Lambda console"
  value       = jsonencode(local.sample_payload)
}

output "aws_cli_invoke_command" {
  description = "AWS CLI command to invoke the Lambda function with the sample payload"
  value       = <<-EOT
    # Command to create payload file
    cat > lambda-payload.json << 'EOF'
    ${jsonencode(local.sample_payload)}
    EOF

    # Command to invoke Lambda function
    aws lambda invoke \\
      --function-name ${aws_lambda_function.this.function_name} \\
      --payload fileb://lambda-payload.json \\
      --region ${data.aws_region.current.name} \\
      --cli-binary-format raw-in-base64-out \\
      lambda-response.json

    # Display the response
    cat lambda-response.json
    
    # Troubleshooting: If you see an import error like:
    # "Unable to import module 'app': attempted relative import with no known parent package"
    # Make sure your Lambda function's handler is correctly configured as "app.lambda_handler"
    # This can be updated using:
    
    aws lambda update-function-configuration \\
      --function-name ${aws_lambda_function.this.function_name} \\
      --handler app.lambda_handler \\
      --region ${data.aws_region.current.name}
  EOT
}
