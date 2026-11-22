mock_provider "aws" {
  override_during = plan
}

variables {
  domain          = "antenna.example"
  zone_id         = "Z0000000000000"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/site"
}

override_resource {
  target          = aws_cloudfront_distribution.site
  override_during = plan
  values = {
    arn         = "arn:aws:cloudfront::123456789012:distribution/E000000000000"
    id          = "E000000000000"
    domain_name = "d000000000000.cloudfront.net"
  }
}

override_resource {
  target          = aws_cloudfront_function.address
  override_during = plan
  values = {
    arn = "arn:aws:cloudfront::123456789012:function/antenna-site-address"
  }
}

override_resource {
  target          = aws_cloudfront_response_headers_policy.site
  override_during = plan
  values = {
    id = "site-headers"
  }
}

override_resource {
  target          = aws_cloudfront_response_headers_policy.setup
  override_during = plan
  values = {
    id = "setup-headers"
  }
}

override_resource {
  target          = aws_s3_bucket.site
  override_during = plan
  values = {
    arn = "arn:aws:s3:::antenna-site-123456789012"
  }
}

# hosting/the-site-is-served-over-https-on-antenna-s-domain
run "https_only_on_the_domain" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition     = aws_cloudfront_distribution.site.aliases == toset(["antenna.example", "www.antenna.example"])
    error_message = "the distribution must answer the domain and www"
  }

  assert {
    condition = alltrue(concat(
      [for b in aws_cloudfront_distribution.site.default_cache_behavior : b.viewer_protocol_policy == "redirect-to-https"],
      [for b in aws_cloudfront_distribution.site.ordered_cache_behavior : b.viewer_protocol_policy == "redirect-to-https"],
    ))
    error_message = "plain HTTP must redirect to HTTPS on every path"
  }

  assert {
    condition     = one(aws_cloudfront_distribution.site.viewer_certificate).minimum_protocol_version == "TLSv1.2_2021"
    error_message = "TLS 1.2 is the minimum"
  }

  assert {
    condition = alltrue([
      for p in [aws_cloudfront_response_headers_policy.site, aws_cloudfront_response_headers_policy.setup] :
      one(one(p.security_headers_config).strict_transport_security).access_control_max_age_sec == 63072000 &&
      one(one(p.security_headers_config).strict_transport_security).include_subdomains &&
      one(one(p.security_headers_config).strict_transport_security).preload
    ])
    error_message = "every page must tell browsers to keep to HTTPS for two years"
  }

  assert {
    condition     = strcontains(aws_cloudfront_function.address.code, "statusCode: 301") && strcontains(aws_cloudfront_function.address.code, "'www.'")
    error_message = "the address function must redirect www permanently"
  }

  assert {
    condition = alltrue(concat(
      [for b in aws_cloudfront_distribution.site.default_cache_behavior : one(b.function_association).function_arn == aws_cloudfront_function.address.arn],
      [for b in aws_cloudfront_distribution.site.ordered_cache_behavior : one(b.function_association).function_arn == aws_cloudfront_function.address.arn],
    ))
    error_message = "every path must go through the address function"
  }

  assert {
    condition     = toset(keys(aws_route53_record.alias)) == toset(["antenna.example A", "antenna.example AAAA", "www.antenna.example A", "www.antenna.example AAAA"])
    error_message = "the domain and www need IPv4 and IPv6 aliases"
  }
}

# hosting/the-site-is-served-over-https-on-antenna-s-domain
run "an_unknown_address_is_not_found" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition = toset([for e in aws_cloudfront_distribution.site.custom_error_response : "${e.error_code} ${e.response_code} ${e.response_page_path}"]) == toset([
      "403 404 /404.html",
      "404 404 /404.html",
    ])
    error_message = "403 and 404 from the bucket must answer /404.html with status 404"
  }

  assert {
    condition     = alltrue([for e in aws_cloudfront_distribution.site.custom_error_response : e.response_code != 200 && !strcontains(e.response_page_path, "index.html")])
    error_message = "no error may fall back to a page with a success status"
  }
}

# hosting/the-site-s-files-cannot-be-read-around-it
run "the_bucket_is_private" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.site.block_public_acls &&
      aws_s3_bucket_public_access_block.site.block_public_policy &&
      aws_s3_bucket_public_access_block.site.ignore_public_acls &&
      aws_s3_bucket_public_access_block.site.restrict_public_buckets
    )
    error_message = "the bucket must block every kind of public access"
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.site.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "object ACLs must be off"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.site.policy).Statement[0].Principal == { Service = "cloudfront.amazonaws.com" }
    error_message = "only CloudFront may read the bucket"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.site.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == "arn:aws:cloudfront::123456789012:distribution/E000000000000"
    error_message = "only this distribution may read the bucket"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.site.policy).Statement[0].Action == "s3:GetObject"
    error_message = "the distribution may only read objects"
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.site.signing_behavior == "always" && aws_cloudfront_origin_access_control.site.origin_access_control_origin_type == "s3"
    error_message = "every request to the bucket must be signed by the distribution"
  }
}

# hosting/nothing-keeps-a-record-of-requests
run "the_distribution_keeps_no_logs" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition     = length(aws_cloudfront_distribution.site.logging_config) == 0
    error_message = "CloudFront standard logs must stay off"
  }

  assert {
    condition = alltrue(concat(
      [for b in aws_cloudfront_distribution.site.default_cache_behavior : b.realtime_log_config_arn == null || b.realtime_log_config_arn == ""],
      [for b in aws_cloudfront_distribution.site.ordered_cache_behavior : b.realtime_log_config_arn == null || b.realtime_log_config_arn == ""],
    ))
    error_message = "no path may have a real-time log"
  }
}

# hosting/pages-run-only-the-site-s-own-code
run "pages_run_only_the_site_s_own_code" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition     = one(one(aws_cloudfront_response_headers_policy.site.security_headers_config).content_security_policy).content_security_policy == "default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    error_message = "the site's CSP must be the string decided in design.md decision 3"
  }

  assert {
    condition     = one(one(aws_cloudfront_response_headers_policy.setup.security_headers_config).content_security_policy).content_security_policy == "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    error_message = "the setup page's CSP must be the string decided in design.md decision 3"
  }

  assert {
    condition = alltrue([
      for p in [aws_cloudfront_response_headers_policy.site, aws_cloudfront_response_headers_policy.setup] :
      length(regexall("script-src[^;]*'unsafe-(inline|eval)'", one(one(p.security_headers_config).content_security_policy).content_security_policy)) == 0
    ])
    error_message = "script-src must never allow inline or eval"
  }

  assert {
    condition = alltrue([
      for p in [aws_cloudfront_response_headers_policy.site, aws_cloudfront_response_headers_policy.setup] :
      strcontains(one(one(p.security_headers_config).content_security_policy).content_security_policy, "frame-ancestors 'none'") &&
      one(one(p.security_headers_config).content_security_policy).override
    ])
    error_message = "no other site may frame a page, and the header must replace one from the bucket"
  }

  assert {
    condition     = [for b in aws_cloudfront_distribution.site.ordered_cache_behavior : b.response_headers_policy_id if b.path_pattern == "/setup*"] == [aws_cloudfront_response_headers_policy.setup.id]
    error_message = "the setup page must get the policy with no script"
  }

  assert {
    condition     = one(aws_cloudfront_distribution.site.default_cache_behavior).response_headers_policy_id == aws_cloudfront_response_headers_policy.site.id
    error_message = "every other page must get the site's policy"
  }
}

# hosting/deploys-come-only-from-main
run "the_site_role_can_only_upload_and_invalidate" {
  command = plan

  module {
    source = "../modules/site"
  }

  assert {
    condition     = aws_iam_role_policy.site_upload.role == "antenna-site"
    error_message = "the upload policy belongs to the antenna-site role"
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.site_upload.policy).Statement == [
      { Effect = "Allow", Action = "s3:ListBucket", Resource = "arn:aws:s3:::antenna-site-123456789012" },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:DeleteObject"], Resource = "arn:aws:s3:::antenna-site-123456789012/*" },
      { Effect = "Allow", Action = "cloudfront:CreateInvalidation", Resource = "arn:aws:cloudfront::123456789012:distribution/E000000000000" },
    ]
    error_message = "the site role may list, write and delete in the site bucket and invalidate the site distribution, nothing else"
  }
}
