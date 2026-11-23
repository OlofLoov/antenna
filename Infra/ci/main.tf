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
      project    = "antuna"
      managed-by = "terraform"
    }
  }
}

variable "github_subject" {
  description = "The repository part of GitHub's immutable OIDC subject, as repo:<owner>@<owner id>/<name>@<repository id>."
  type        = string

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9._-]+@[0-9]+$", var.github_subject))
    error_message = "github_subject must be repo:<owner>@<owner id>/<name>@<repository id>."
  }
}

variable "state_bucket" {
  description = "The bucket holding Terraform state, where a plan writes its lock file."
  type        = string
}

locals {
  issuer = "token.actions.githubusercontent.com"

  subjects = {
    diff   = "${var.github_subject}:pull_request"
    deploy = "${var.github_subject}:environment:production"
    site   = "${var.github_subject}:ref:refs/heads/main"
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
  name               = "antuna-diff"
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
  name               = "antuna-deploy"
  assume_role_policy = local.trust.deploy
}

resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "site" {
  name               = "antuna-site"
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
