mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/rg-servicefabric"
      output = {
        properties = {
          clusterEndpoint   = "https://westus3.servicefabric.azure.com/runtime/clusters/example"
          clusterId         = "00000000-0000-0000-0000-000000000001"
          provisioningState = "Succeeded"
          dnsSettings = {
            fqdn = "sfitexample-cn.westus3.cloudapp.azure.com"
          }
        }
      }
    }
  }
  mock_resource "azapi_resource_action" {
    defaults = {
      output = {
        properties = {
          secretUriWithVersion = "https://kv-example.vault.azure.net/secrets/cluster-certificate/version"
        }
        value = [{
          code    = "ComponentStatus/StdOut/succeeded"
          message = "AVM_HEALTH_OK_created AVM_DNS_OK_created"
        }]
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000002"
      object_id                = "00000000-0000-0000-0000-000000000003"
    }
  }
}

run "standalone_common_name_example" {
  command = apply

  module {
    source = "./examples/default"
  }

  variables {
    enable_telemetry = false
    fixture_settings = {
      name_prefix              = "sfitexample"
      location                 = "westus3"
      vm_sku                   = "Standard_D2s_v5"
      management_source_prefix = "192.0.2.1/32"
      certificate_common_name  = "sfitexample.servicefabric.test"
      certificate_thumbprint   = "0123456789012345678901234567890123456789"
    }
    fixture_secrets = {
      admin_password     = "mock-password-not-a-credential"
      certificate_secret = "mock-certificate-not-a-pfx"
    }
  }

  override_resource {
    target = module.cluster.module.cluster.azapi_resource.this
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric/providers/Microsoft.ServiceFabric/clusters/sfitexample-cn"
      output = {
        properties = {
          clusterEndpoint = "https://westus3.servicefabric.azure.com/runtime/clusters/example"
          clusterId       = "00000000-0000-0000-0000-000000000001"
        }
      }
    }
  }

  assert {
    condition     = output.name == "sfitexample-cn" && output.management_endpoint == "https://sfitexample-cn.westus3.cloudapp.azure.com:19080"
    error_message = "The example must derive its cluster name and management endpoint from its own infrastructure."
  }

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric/providers/Microsoft.ServiceFabric/clusters/sfitexample-cn" && output.cluster_id == "00000000-0000-0000-0000-000000000001"
    error_message = "The example must expose the resource ID and Azure-generated cluster identifier."
  }

  assert {
    condition     = output.cluster_endpoint == "https://westus3.servicefabric.azure.com/runtime/clusters/example"
    error_message = "The example must expose the resource-provider endpoint needed by the VM extension."
  }

  assert {
    condition     = output.runtime_health_verified
    error_message = "The example must include the node-side operational health check."
  }
}
