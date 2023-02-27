variable "app_config" {}

data "aws_acm_certificate" "entity" {
  domain   = var.app_config.base_domain
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "selected" {
  name     = ""
  provider = aws.route53
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = "${var.app_config.customer_name}.${var.app_config.base_domain}"

  zone_id = data.aws_route53_zone.selected.zone_id

  #   subject_alternative_names = [
  #     "${var.app_config.customer_name}.gov.${var.app_config.base_domain}"
  #   ]

  wait_for_validation = true

  tags = {
    Name = "${var.app_config.customer_name}.${var.app_config.base_domain}"
  }
}
