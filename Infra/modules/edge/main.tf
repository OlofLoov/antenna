terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }
}

variable "domain" {
  description = "Antuna's own domain, without www."
  type        = string
}

variable "alert_email" {
  description = "Where the budget and cost anomaly alerts go."
  type        = string
  sensitive   = true
}

variable "monthly_budget_usd" {
  description = "The monthly AWS budget the alerts measure against."
  type        = number
  default     = 20
}

locals {
  site_names = [var.domain, "www.${var.domain}"]
}

resource "aws_route53_zone" "this" {
  name = var.domain
}

resource "aws_acm_certificate" "site" {
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_validation" {
  for_each = toset(local.site_names)

  zone_id         = aws_route53_zone.this.zone_id
  allow_overwrite = true
  ttl             = 300
  name            = one([for o in aws_acm_certificate.site.domain_validation_options : o.resource_record_name if o.domain_name == each.key])
  type            = one([for o in aws_acm_certificate.site.domain_validation_options : o.resource_record_type if o.domain_name == each.key])
  records         = [one([for o in aws_acm_certificate.site.domain_validation_options : o.resource_record_value if o.domain_name == each.key])]
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.site_validation : r.fqdn]
}

resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "CAA"
  ttl     = 3600
  records = ["0 issue \"amazon.com\""]
}

resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 -all"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DMARC1; p=reject"]
}

resource "aws_budgets_budget" "monthly" {
  name         = "antuna-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_ce_anomaly_monitor" "services" {
  name              = "antuna-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "owner" {
  name             = "antuna-owner"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["5"]
    }
  }
}

output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "name_servers" {
  value = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.site.certificate_arn
}
