provider "aws" {
  region = "us-west-2"
}

# Example 1: Using local source code
module "template_automation_from_source" {
  source = "../.."

  name_prefix = "template-automation-source"
  
  lambda_config = {
    create_zipfile = true
    source_path    = "../../template_automation"
    runtime        = "python3.9"
    memory_size    = 256
    timeout        = 300
    environment_variables = {
      SECRET_NAME = "github/token"
    }
  }

  parameter_store_prefix = "/template-automation"
  ssm_parameters = {
    "TEMPLATE_REPO_NAME"         = "my-template-repo"
    "GITHUB_API"                 = "https://api.github.com"
    "GITHUB_ORG_NAME"           = "my-org"
    "TEMPLATE_CONFIG_FILE"       = "config.json"
  }

  tags = {
    Environment = "dev"
    Project     = "template-automation"
  }
}

# Example 2: Using pre-built zip file
module "template_automation_from_zip" {
  source = "../.."

  name_prefix = "template-automation-zip"
  
  lambda_config = {
    zip_path    = "../../lambda.zip"
    runtime     = "python3.9"
    memory_size = 256
    timeout     = 300
    environment_variables = {
      SECRET_NAME = "github/token"
    }
  }

  parameter_store_prefix = "/template-automation"
  ssm_parameters = {
    "TEMPLATE_REPO_NAME"         = "my-template-repo"
    "GITHUB_API"                 = "https://api.github.com"
    "GITHUB_ORG_NAME"           = "my-org"
  }

  tags = {
    Environment = "dev"
    Project     = "template-automation"
  }
}

# Example 3: Using S3 source
module "template_automation_from_s3" {
  source = "../.."

  name_prefix = "template-automation-s3"
  
  lambda_config = {
    runtime     = "python3.9"
    memory_size = 256
    timeout     = 300
    environment_variables = {
      SECRET_NAME = "github/token"
    }
    s3 = {
      bucket = "my-lambda-bucket"
      key    = "lambda-functions/template-automation.zip"
      # object_version is optional
    }
  }

  parameter_store_prefix = "/template-automation"
  ssm_parameters = {
    "TEMPLATE_REPO_NAME"         = "my-template-repo"
    "GITHUB_API"                 = "https://api.github.com"
    "GITHUB_ORG_NAME"           = "my-org"
  }

  tags = {
    Environment = "dev"
    Project     = "template-automation"
  }
}
