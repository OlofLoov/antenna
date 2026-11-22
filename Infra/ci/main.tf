terraform {
  required_version = "1.17.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }

  backend "s3" {
    key          = "ci.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      project    = "antenna"
      managed-by = "terraform"
    }
  }
}

variable "github_repository" {
  description = "The repository whose workflows may assume the roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be owner/name."
  }
}

variable "state_bucket" {
  description = "The bucket holding Terraform state, where a plan writes its lock file."
  type        = string
}

locals {
  issuer = "token.actions.githubusercontent.com"

  subjects = {
    diff   = "repo:${var.github_repository}:pull_request"
    deploy = "repo:${var.github_repository}:environment:production"
    site   = "repo:${var.github_repository}:ref:refs/heads/main"
  }

  trust = {
    for role, subject in local.subjects : role => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.issuer}:aud" = "sts.amazonaws.com"
            "${local.issuer}:sub" = subject
          }
        }
      }]
    })
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "diff" {
  name               = "antenna-diff"
  assume_role_policy = local.trust.diff
}

resource "aws_iam_role_policy_attachment" "diff_read_only" {
  role       = aws_iam_role.diff.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "diff_lock" {
  name = "state-lock"
  role = aws_iam_role.diff.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:aws:s3:::${var.state_bucket}/*.tflock"
    }]
  })
}

resource "aws_iam_role" "deploy" {
  name               = "antenna-deploy"
  assume_role_policy = local.trust.deploy
}

resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "site" {
  name               = "antenna-site"
  assume_role_policy = local.trust.site
}

output "diff_role_arn" {
  value = aws_iam_role.diff.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "site_role_arn" {
  value = aws_iam_role.site.arn
}
