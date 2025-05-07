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

variable "github_api_url" {
  description = "URL for the GitHub Enterprise API"
  type        = string
  default     = "https://api.github.com"
}

variable "github_org_name" {
  description = "GitHub organization name"
  type        = string
}

variable "template_repo_name" {
  description = "GitHub repository name for the template"
  type        = string
}

variable "template_config_file" {
  description = "Name of the config file to write in new repositories"
  type        = string
  default     = "config.json"
}

variable "github_commit_author_name" {
  description = "Name for commit author"
  type        = string
  default     = "Template Automation"
}

variable "github_commit_author_email" {
  description = "Email for commit author"
  type        = string
  default     = "automation@example.com"
}

variable "template_topics" {
  description = "Topics to assign to new repositories (comma-separated string)"
  type        = string
  default     = "infrastructure"
}

variable "lambda_config" {
  description = "Lambda function configuration object"
  type = object({
    memory_size = optional(number, 512)
    timeout     = optional(number, 300)

    # Environment configuration
    environment_variables = optional(map(string), {})

    # Container image configuration
    image_uri = string
    image_config = optional(object({
      command           = optional(list(string))
      entry_point       = optional(list(string))
      working_directory = optional(string)
    }))
  })
}

variable "github_token" {
  description = "GitHub token configuration"
  type = object({
    secret_name = string
    token       = optional(string)
  })
  sensitive = true
}



variable "allowed_iam_arns" {
  description = "List of IAM ARNs allowed to invoke the Lambda function when IAM auth is enabled"
  type        = list(string)
  default     = []
}
