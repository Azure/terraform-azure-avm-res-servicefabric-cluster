mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      output = {
        properties = {
          clusterEndpoint = "https://westus3.servicefabric.azure.com/runtime/clusters/example"
          clusterId       = "00000000-0000-0000-0000-000000000001"
        }
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

run "normalizes_issuer_thumbprints" {
  command = apply

  variables {
    name                = "sf-certificate-normalization"
    parent_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric"
    location            = "westus3"
    management_endpoint = "https://sf.example.com:19080"
    enable_telemetry    = false
    reliability_level   = "Bronze"
    node_types = {
      primary = {
        name              = "primary"
        is_primary        = true
        vm_instance_count = 3
      }
    }
    certificate_common_names = {
      common_names = [{
        certificate_common_name       = "sf.example.com"
        certificate_issuer_thumbprint = "ABCDEF0123456789ABCDEF0123456789ABCDEF01"
      }]
    }
    client_certificate_common_names = [{
      certificate_common_name       = "admin.example.com"
      certificate_issuer_thumbprint = "ABCDEF0123456789ABCDEF0123456789ABCDEF01"
      is_admin                      = true
    }]
    reverse_proxy_certificate_common_names = {
      common_names = [{
        certificate_common_name       = "proxy.example.com"
        certificate_issuer_thumbprint = "ABCDEF0123456789ABCDEF0123456789ABCDEF01"
      }]
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.certificateCommonNames.commonNames[0].certificateIssuerThumbprint == "abcdef0123456789abcdef0123456789abcdef01" &&
      azapi_resource.this.body.properties.clientCertificateCommonNames[0].certificateIssuerThumbprint == "abcdef0123456789abcdef0123456789abcdef01" &&
      azapi_resource.this.body.properties.reverseProxyCertificateCommonNames.commonNames[0].certificateIssuerThumbprint == "abcdef0123456789abcdef0123456789abcdef01"
    )
    error_message = "All issuer thumbprint surfaces must use Azure's lowercase canonical representation."
  }
}
