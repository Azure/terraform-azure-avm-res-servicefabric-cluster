locals {
  settings = var.fixture_settings
  secrets  = var.fixture_secrets
  name     = "${local.settings.name_prefix}-${var.certificate_mode == "thumbprint" ? "tp" : "cn"}"
  tags = {
    purpose = "avm-servicefabric-integration"
    phase   = var.configure_optional_features ? "configured" : "baseline"
  }
  common_names = {
    common_names = [{
      certificate_common_name       = local.settings.certificate_common_name
      certificate_issuer_thumbprint = local.settings.certificate_thumbprint
    }]
  }
}
