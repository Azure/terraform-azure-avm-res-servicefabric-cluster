provider "azapi" {}

module "cluster" {
  source = "../../tests/integration/setup"

  fixture_secrets             = var.fixture_secrets
  fixture_settings            = var.fixture_settings
  certificate_mode            = "common_name"
  configure_optional_features = true
  enable_telemetry            = var.enable_telemetry
}
