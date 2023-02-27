variable "name" {}
variable "public_subnets" {}
variable "vpc_id" {}
variable "app_config" {}

data "aws_route53_zone" "selected" {
  name     = ""
  provider = aws.route53
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = lower(join(".", var.app_config.customer_name, var.app_config.base_domain))

  create_route53_records  = false
  validation_record_fqdns = module.route53_records.validation_route53_record_fqdns
}

module "route53_records" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.route53
  }

  create_certificate          = false
  create_route53_records_only = true

  distinct_domain_names = module.acm.distinct_domain_names
  zone_id               = data.aws_route53_zone.selected.zone_id

  acm_certificate_domain_validation_options = module.acm.acm_certificate_domain_validation_options
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name    = replace(var.vault_instance, "_", "-")
  vpc_id  = var.vpc_id
  subnets = var.public_subnets

  security_groups = [
    aws_security_group.vault.id
  ]
  target_groups = [
    {
      name_prefix      = "tg1-"
      backend_protocol = "HTTPS"
      backend_port     = 8200
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/v1/sys/health"
        protocol            = "HTTPS"
        matcher             = 200
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
      }
      targets = {
        vault = {
          target_id = aws_instance.vault.id
          port      = 8200
        }
      }
    },
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = module.acm.acm_certificate_arn
      target_group_index = 0
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
}

resource "aws_route53_record" "entity" {
  provider = aws.route53
  name     = ""
  zone_id  = data.aws_route53_zone.selected.zone_id
  type     = "CNAME"
  ttl      = 300
  records = [
    module.alb.lb_dns_name
  ]
}

