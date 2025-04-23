variable "name_prefix" {
  description = "Prefix to be used for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "parameter_store_prefix" {
  description = "Prefix for SSM parameters (e.g., /template-automation)"
  type        = string
  default     = "/template-automation"
}

variable "ssm_parameters" {
  description = "Map of SSM parameters to create for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "lambda_config" {
  description = "Lambda function configuration object"
  type = object({
    runtime     = optional(string, "python3.9")
    timeout     = optional(number, 300)
    memory_size = optional(number, 256)
    
    # Environment configuration
    environment_variables = optional(map(string), {})
    
    # Source configuration - one of these must be provided
    create_zipfile = optional(bool, false)
    source_path    = optional(string)
    zip_path       = optional(string)
    
    # S3 source configuration
    s3 = optional(object({
      bucket          = string
      key             = string
      object_version  = optional(string)
    }))
  })

  validation {
    condition = (
      (var.lambda_config.create_zipfile && var.lambda_config.source_path != null) ||
      (!var.lambda_config.create_zipfile && var.lambda_config.s3 == null && var.lambda_config.zip_path != null) ||
      (!var.lambda_config.create_zipfile && var.lambda_config.s3 != null)
    )
    error_message = "One of the following combinations must be provided: (create_zipfile = true and source_path), (zip_path), or s3 configuration"
  }
}
