mock_provider "aws" {
  override_during = plan
}

variables {
  domain      = "antuna.example"
  alert_email = "owner@example.com"
}

override_resource {
  target          = aws_acm_certificate.site
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
run "one_certificate_for_the_domain_and_www" {
  command = plan

  module {
    source = "../modules/edge"
  }

  assert {
    condition     = aws_acm_certificate.site.domain_name == "antuna.example"
    error_message = "the certificate must be for the bare domain"
  }

  assert {
    condition     = aws_acm_certificate.site.subject_alternative_names == toset(["www.antuna.example"])
    error_message = "the certificate must also cover www"
  }

  assert {
    condition     = aws_acm_certificate.site.validation_method == "DNS"
    error_message = "the certificate must validate through the zone"
  }

  assert {
    condition     = toset([for r in aws_route53_record.site_validation : r.name]) == toset(["_a.antuna.example.", "_b.www.antuna.example."])
    error_message = "each name on the certificate needs its validation record"
  }

  assert {
    condition     = aws_route53_record.caa.records == toset(["0 issue \"amazon.com\""])
    error_message = "only Amazon may issue certificates for the domain"
  }
}

# hosting/the-domain-receives-no-email
run "the_domain_publishes_no_mail_records" {
  command = plan

  module {
    source = "../modules/edge"
  }

  assert {
    condition     = aws_route53_record.spf.name == "antuna.example" && aws_route53_record.spf.type == "TXT" && aws_route53_record.spf.records == toset(["v=spf1 -all"])
    error_message = "the SPF record must allow no sender"
  }

  assert {
    condition     = aws_route53_record.dmarc.name == "_dmarc.antuna.example" && aws_route53_record.dmarc.records == toset(["v=DMARC1; p=reject"])
    error_message = "DMARC must reject mail that claims the domain"
  }

  assert {
    condition = alltrue([
      for r in concat([aws_route53_record.caa, aws_route53_record.spf, aws_route53_record.dmarc], values(aws_route53_record.site_validation)) :
      r.type != "MX"
    ])
    error_message = "the zone must have no MX record"
  }
}

# hosting/the-owner-hears-about-cost-before-it-grows
run "the_budget_alerts_at_half_and_at_the_whole" {
  command = plan

  module {
    source = "../modules/edge"
  }

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "20" && aws_budgets_budget.monthly.limit_unit == "USD" && aws_budgets_budget.monthly.time_unit == "MONTHLY"
    error_message = "the budget must be $20 a month"
  }

  assert {
    condition = toset([for n in aws_budgets_budget.monthly.notification : "${n.notification_type} ${n.threshold} ${n.threshold_type}"]) == toset([
      "ACTUAL 50 PERCENTAGE",
      "ACTUAL 100 PERCENTAGE",
      "FORECASTED 100 PERCENTAGE",
    ])
    error_message = "the alerts must fire at 50% actual, 100% actual and 100% forecast"
  }

  assert {
    condition     = alltrue([for n in aws_budgets_budget.monthly.notification : n.subscriber_email_addresses == toset(["owner@example.com"])])
    error_message = "every budget alert must reach the owner"
  }

  assert {
    condition     = aws_ce_anomaly_monitor.services.monitor_type == "DIMENSIONAL" && aws_ce_anomaly_monitor.services.monitor_dimension == "SERVICE"
    error_message = "the anomaly monitor must watch every service"
  }

  assert {
    condition     = aws_ce_anomaly_subscription.owner.frequency == "DAILY"
    error_message = "anomaly alerts must arrive the same day"
  }
}
