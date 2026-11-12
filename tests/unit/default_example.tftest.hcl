mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric/providers/Microsoft.ServiceFabric/clusters/sf-common-name-example"
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

run "common_name_usage_example" {
  command = apply

  module {
    source = "./examples/default"
  }

  variables {
    admin_client_certificate_common_name       = "sf-admin.example.com"
    admin_client_certificate_issuer_thumbprint = "1123456789012345678901234567890123456789"
    certificate_common_name                    = "sf.example.com"
    certificate_issuer_thumbprint              = "0123456789012345678901234567890123456789"
    enable_telemetry                           = false
    management_endpoint                        = "https://sf.example.com:19080"
    parent_id                                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric"
  }

  assert {
    condition     = output.name == "sf-common-name-example" && output.management_endpoint == var.management_endpoint
    error_message = "The example must pass the cluster name and existing management endpoint to the module."
  }

  assert {
    condition     = output.resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-servicefabric/providers/Microsoft.ServiceFabric/clusters/sf-common-name-example" && output.cluster_id == "00000000-0000-0000-0000-000000000001"
    error_message = "The example must expose the resource ID and Azure-generated cluster identifier."
  }

  assert {
    condition     = output.cluster_endpoint == "https://westus3.servicefabric.azure.com/runtime/clusters/example"
    error_message = "The example must expose the resource-provider endpoint needed by the VM extension."
  }
}
