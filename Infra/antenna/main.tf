terraform {
  required_version = "1.17.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }

  backend "s3" {
    key          = "antenna.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  tags = {
    project    = "antenna"
    managed-by = "terraform"
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

variable "domain" {
  description = "Antenna's own domain, without www, from the ANTENNA_DOMAIN repository variable."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.domain)) && !startswith(var.domain, "www.")
    error_message = "domain must be a lowercase name such as example.app, without www."
  }
}

variable "alert_email" {
  description = "Where the budget and cost anomaly alerts go, from the AWS_ALERT_EMAIL repository variable."
  type        = string
  sensitive   = true
}

module "edge" {
  source = "../modules/edge"

  providers = {
    aws = aws.us_east_1
  }

  domain      = var.domain
  alert_email = var.alert_email
}

module "site" {
  source = "../modules/site"

  domain          = var.domain
  zone_id         = module.edge.zone_id
  certificate_arn = module.edge.certificate_arn
}

output "name_servers" {
  value = module.edge.name_servers
}

output "site_bucket" {
  value = module.site.bucket
}

output "site_distribution_id" {
  value = module.site.distribution_id
}
