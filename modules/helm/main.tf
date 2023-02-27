variable "app_config" {}

# resource "random_password" "database" {
#   length  = 32
#   special = true
# }

resource "helm_release" "app" {
  name    = var.app_config.helm.chart_name
  chart   = var.app_config.helm.helm_chart
  version = var.app_config.helm.chart_version
  namespace        = var.app_config.helm.chart_namespace
  timeout          = var.app_config.helm.timeout
  create_namespace = true

  values = [
    "${file("values.yaml")}"
  ]
}