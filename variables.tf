variable "name_prefix" {
  description = "Prefix to be used for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "log_retention_in_days" {
  description = "Number of days to retain Lambda CloudWatch log events"
  type        = number
  default     = 14
}

variable "parameter_store_prefix" {
  description = "Prefix for SSM parameters. Defaults to /<name_prefix> to avoid conflicts between deployments."
  type        = string
  default     = null
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

variable "repo_visibility" {
  description = "Default visibility for newly created repositories. GHE enterprise policies often block 'private'; use 'internal' (visible to org members) or 'public'. Overrides the REPO_VISIBILITY env var baked into the container."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["private", "internal", "public"], var.repo_visibility)
    error_message = "repo_visibility must be one of: private, internal, public."
  }
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

    # VPC configuration
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
  })
}

variable "github_token" {
  description = "GitHub token configuration"
  type = object({
    secret_name = string
    token       = optional(string)
    kms_key_id  = optional(string)
  })
  sensitive = true
}



variable "allowed_iam_arns" {
  description = "List of IAM ARNs allowed to invoke the Lambda function when IAM auth is enabled"
  type        = list(string)
  default     = []
}

variable "trusted_aws_accounts" {
  description = <<-EOT
    Map of friendly account name => account config for accounts outside the home
    AWS Organization that need cross-account Service Catalog → Lambda invocation.

    Service Catalog (not CloudFormation) invokes Lambda Custom Resources using the
    SC launch role's assumed-role identity. The Lambda resource policy must grant
    the specific IAM role ARN of that launch role.

    NOTE: GovCloud Lambda add-permission will be blocked if the function policy
    contains any raw AWS-principal statement (role/user ARN or ID). Remove any
    such manually-added statements before applying.

    Fields:
      account_id       - (required) 12-digit AWS account ID
      enabled          - (required) true to create the permission
      launch_role_name - (optional) IAM role name of the SC launch role in the
                         target account; permission is only created when set

    Example:
      trusted_aws_accounts = {
        "lab-gov-operations-nonprod" = {
          account_id       = "036728032133"
          enabled          = true
          launch_role_name = "r-ent-servicecatalog-eksterragrunt-launch-role"
        }
      }
  EOT
  type = map(object({
    account_id       = string
    enabled          = bool
    launch_role_name = optional(string, "")
  }))
  default = {}
}
