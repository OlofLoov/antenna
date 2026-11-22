mock_provider "aws" {
  override_during = plan
}

variables {
  github_repository = "example/antenna"
  state_bucket      = "antenna-terraform-state-123456789012"
}

override_resource {
  target          = aws_iam_openid_connect_provider.github
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
}

# hosting/deploys-come-only-from-main
run "each_role_trusts_one_subject" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "the provider must be GitHub's token issuer"
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github.client_id_list == toset(["sts.amazonaws.com"])
    error_message = "the provider must accept only the STS audience"
  }

  assert {
    condition     = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/antenna:environment:production"
    error_message = "antenna-deploy must trust only the production environment"
  }

  assert {
    condition     = jsondecode(aws_iam_role.site.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/antenna:ref:refs/heads/main"
    error_message = "antenna-site must trust only the main branch"
  }

  assert {
    condition     = jsondecode(aws_iam_role.diff.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/antenna:pull_request"
    error_message = "antenna-diff must trust only pull requests"
  }

  assert {
    condition = alltrue([
      for role in [aws_iam_role.diff, aws_iam_role.deploy, aws_iam_role.site] :
      jsondecode(role.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    ])
    error_message = "every role must require the STS audience"
  }

  assert {
    condition = alltrue([
      for role in [aws_iam_role.diff, aws_iam_role.deploy, aws_iam_role.site] :
      length(jsondecode(role.assume_role_policy).Statement) == 1 &&
      keys(jsondecode(role.assume_role_policy).Statement[0].Condition) == ["StringEquals"]
    ])
    error_message = "a trust policy must have one statement matched exactly, with no wildcard condition"
  }
}

# hosting/deploys-come-only-from-main
run "the_pull_request_role_cannot_change_aws" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.diff_read_only.policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "antenna-diff must start from read-only access"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.diff_lock.policy).Statement[0].Resource == "arn:aws:s3:::antenna-terraform-state-123456789012/*.tflock"
    error_message = "antenna-diff may write only the state lock files"
  }

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.diff_lock.policy).Statement[0].Action) == toset(["s3:PutObject", "s3:DeleteObject"])
    error_message = "antenna-diff may only create and remove its lock"
  }
}

run "a_repository_name_without_owner_is_refused" {
  command = plan

  variables {
    github_repository = "antenna"
  }

  expect_failures = [var.github_repository]
}
