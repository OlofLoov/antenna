mock_provider "aws" {
  override_during = plan
}

mock_provider "aws" {
  alias           = "us_east_1"
  override_during = plan
}

variables {
  domain      = "antuna.example"
  alert_email = "owner@example.com"
}

override_resource {
  target          = module.edge.aws_acm_certificate.site
  override_during = plan
  values = {
    arn = "arn:aws:acm:us-east-1:123456789012:certificate/site"
    domain_validation_options = [
      {
        domain_name           = "antuna.example"
        resource_record_name  = "_a.antuna.example."
        resource_record_type  = "CNAME"
        resource_record_value = "_a.acm-validations.aws."
      },
      {
        domain_name           = "www.antuna.example"
        resource_record_name  = "_b.www.antuna.example."
        resource_record_type  = "CNAME"
        resource_record_value = "_b.acm-validations.aws."
      },
    ]
  }
}

# hosting/the-site-is-served-over-https-on-antuna-s-domain
run "the_modules_connect" {
  command = plan

  assert {
    condition     = startswith(output.site_bucket, "antuna-site-")
    error_message = "the root must name the site bucket for SITE_BUCKET"
  }
}

run "a_www_domain_is_refused" {
  command = plan

  variables {
    domain = "www.antuna.example"
  }

  expect_failures = [var.domain]
}
