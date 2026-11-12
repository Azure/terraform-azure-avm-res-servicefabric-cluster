provider "azapi" {}

module "cluster" {
  source = "../../"

  location            = var.location
  management_endpoint = var.management_endpoint
  name                = var.name
  node_types = {
    primary = {
      name                        = var.primary_node_type_name
      is_primary                  = true
      vm_instance_count           = 3
      durability_level            = "Bronze"
      reverse_proxy_endpoint_port = 19081
      application_ports           = { start_port = 20000, end_port = 30000 }
      ephemeral_ports             = { start_port = 49152, end_port = 65534 }
    }
  }
  parent_id       = var.parent_id
  add_on_features = ["DnsService"]
  certificate_common_names = {
    common_names = [{
      certificate_common_name       = var.certificate_common_name
      certificate_issuer_thumbprint = var.certificate_issuer_thumbprint
    }]
  }
  client_certificate_common_names = [{
    certificate_common_name       = var.admin_client_certificate_common_name
    certificate_issuer_thumbprint = var.admin_client_certificate_issuer_thumbprint
    is_admin                      = true
  }]
  enable_telemetry = var.enable_telemetry
  fabric_settings = {
    Security = { ClusterProtectionLevel = "EncryptAndSign" }
  }
  reliability_level = "Bronze"
  reverse_proxy_certificate_common_names = {
    common_names = [{
      certificate_common_name = var.certificate_common_name
    }]
  }
  tags = {
    environment = "example"
  }
}
