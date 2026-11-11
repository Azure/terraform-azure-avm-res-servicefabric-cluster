mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ServiceFabric/clusters/sf-test"
      output = {
        properties = {
          clusterEndpoint = "https://westus3.servicefabric.azure.com/runtime/clusters/test"
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

variables {
  enable_telemetry    = false
  location            = "westus3"
  name                = "sf-test"
  parent_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  management_endpoint = "https://sf-test.westus3.cloudapp.azure.com:19080"
  certificate = {
    thumbprint = "0123456789012345678901234567890123456789"
  }
  node_types = {
    primary = {
      name              = "primary"
      is_primary        = true
      vm_instance_count = 5
    }
  }
  tags = {
    environment = "test"
  }
}

run "cluster_defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.ServiceFabric/clusters@2021-06-01" && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The module must deploy a regular Service Fabric cluster in the supplied resource group and region."
  }

  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.tags == var.tags
    error_message = "The cluster name and tags must match the inputs."
  }

  assert {
    condition     = azapi_resource.this.body.properties.reliabilityLevel == "Silver" && azapi_resource.this.body.properties.upgradeMode == "Automatic" && azapi_resource.this.body.properties.vmImage == "Windows"
    error_message = "The default cluster must use Silver reliability, Automatic upgrades, and Windows."
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.nodeTypes) == 1 && azapi_resource.this.body.properties.nodeTypes[0].isPrimary && azapi_resource.this.body.properties.nodeTypes[0].vmInstanceCount == 5 && azapi_resource.this.body.properties.nodeTypes[0].clientConnectionEndpointPort == 19000 && azapi_resource.this.body.properties.nodeTypes[0].httpGatewayEndpointPort == 19080
    error_message = "The cluster must contain the supplied primary node type with default gateway ports."
  }

  assert {
    condition     = azapi_resource.this.body.properties.certificate.thumbprint == var.certificate.thumbprint && azapi_resource.this.body.properties.certificate.x509StoreName == "My"
    error_message = "The server certificate must be mapped with the default My certificate store."
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.fabricSettings) == 0 && length(azapi_resource.this.body.properties.addOnFeatures) == 0 && !azapi_resource.this.body.properties.eventStoreServiceEnabled
    error_message = "Optional collections must be empty and EventStore disabled by default."
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "reverseProxyCertificate") && !contains(keys(azapi_resource.this.body.properties), "reverseProxyCertificateCommonNames") && !contains(keys(azapi_resource.this.body.properties), "upgradeDescription")
    error_message = "Reverse-proxy certificates and upgrade policies must be omitted unless configured."
  }

  assert {
    condition = toset(azapi_resource.this.replace_triggers_refs) == toset([
      "properties.managementEndpoint",
      "properties.nodeTypes[?isPrimary].name",
      "properties.vmImage",
    ])
    error_message = "Replacement triggers must cover the management endpoint, primary node type name, and VM image, without replacing for instance-count changes."
  }

  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.management_endpoint == var.management_endpoint
    error_message = "Cluster ID, name, and management endpoint outputs must match the resource."
  }

  assert {
    condition     = output.cluster_endpoint == "https://westus3.servicefabric.azure.com/runtime/clusters/test" && output.cluster_id == "00000000-0000-0000-0000-000000000001"
    error_message = "Computed outputs must use the exported resource-provider endpoint and cluster identifier."
  }
}

run "optional_configuration" {
  command = apply

  variables {
    certificate = null
    certificate_common_names = {
      common_names = [{
        certificate_common_name       = "sf-test.example.com"
        certificate_issuer_thumbprint = "0123456789012345678901234567890123456789"
      }]
    }
    reverse_proxy_certificate = {
      thumbprint           = "3123456789012345678901234567890123456789"
      thumbprint_secondary = "4123456789012345678901234567890123456789"
    }
    upgrade_policy = {
      force_restart_enabled             = true
      health_check_retry_timeout        = "00:30:00"
      health_check_stable_duration      = "00:02:00"
      health_check_wait_duration        = "00:00:45"
      upgrade_domain_timeout            = "03:00:00"
      upgrade_replica_set_check_timeout = "1.00:00:00.1234567"
      upgrade_timeout                   = "1.12:00:00"
      health_policy = {
        max_unhealthy_applications_percent = 10
        max_unhealthy_nodes_percent        = 20
      }
      delta_health_policy = {
        max_delta_unhealthy_applications_percent         = 30
        max_delta_unhealthy_nodes_percent                = 40
        max_upgrade_domain_delta_unhealthy_nodes_percent = 50
      }
    }
    client_certificate_thumbprints = [{
      certificate_thumbprint = "1123456789012345678901234567890123456789"
      is_admin               = false
    }]
    client_certificate_common_names = [{
      certificate_common_name       = "sf-client.example.com"
      certificate_issuer_thumbprint = "2123456789012345678901234567890123456789"
      is_admin                      = true
    }]
    azure_active_directory = {
      tenant_id           = "00000000-0000-0000-0000-000000000002"
      cluster_application = "00000000-0000-0000-0000-000000000003"
      client_application  = "00000000-0000-0000-0000-000000000004"
    }
    diagnostics_storage_account_config = {
      storage_account_name                 = "sfdiagnostics"
      protected_account_key_name           = "StorageAccountKey1"
      protected_account_key_name_secondary = "StorageAccountKey2"
      blob_endpoint                        = "https://sfdiagnostics.blob.core.windows.net/"
      queue_endpoint                       = "https://sfdiagnostics.queue.core.windows.net/"
      table_endpoint                       = "https://sfdiagnostics.table.core.windows.net/"
    }
    fabric_settings = {
      Security = {
        ClusterProtectionLevel = "EncryptAndSign"
      }
    }
    add_on_features             = ["DnsService", "RepairManager"]
    event_store_service_enabled = true
    upgrade_mode                = "Manual"
    cluster_code_version        = "9.1.1833.9590"
    vm_image                    = "Linux"
    sf_zonal_upgrade_mode       = "Hierarchical"
    vmss_zonal_upgrade_mode     = "Parallel"
    node_types = {
      primary = {
        name                        = "primary"
        is_primary                  = true
        vm_instance_count           = 9
        durability_level            = "Silver"
        multiple_availability_zones = true
        application_ports           = { start_port = 20000, end_port = 30000 }
        ephemeral_ports             = { start_port = 49152, end_port = 65534 }
        reverse_proxy_endpoint_port = 19081
        capacities                  = { Memory = "8192" }
        placement_properties        = { Workload = "system" }
      }
      worker = {
        name              = "worker"
        is_primary        = false
        vm_instance_count = 2
        is_stateless      = true
      }
    }
    retry = {
      error_message_regex = ["ScopeLocked"]
      interval_seconds    = 5
    }
    timeouts = {
      create = "1h"
      delete = "30m"
    }
    ignore_body_changes = {
      servicefabric_clusters = ["properties.fabricSettings"]
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.certificateCommonNames.commonNames[0].certificateCommonName == "sf-test.example.com" && azapi_resource.this.body.properties.clientCertificateThumbprints[0].isAdmin == false && azapi_resource.this.body.properties.clientCertificateCommonNames[0].isAdmin
    error_message = "Common-name server certificates and client certificate permissions must be mapped."
  }

  assert {
    condition     = azapi_resource.this.body.properties.azureActiveDirectory.tenantId == var.azure_active_directory.tenant_id && azapi_resource.this.body.properties.diagnosticsStorageAccountConfig.protectedAccountKeyName2 == "StorageAccountKey2"
    error_message = "Entra authentication and protected diagnostics key-setting names must be mapped."
  }

  assert {
    condition     = azapi_resource.this.body.properties.fabricSettings[0].parameters[0].value == "EncryptAndSign" && toset(azapi_resource.this.body.properties.addOnFeatures) == var.add_on_features && azapi_resource.this.body.properties.eventStoreServiceEnabled
    error_message = "Fabric settings, add-on features, and EventStore must reflect the inputs."
  }

  assert {
    condition     = azapi_resource.this.body.properties.upgradeMode == "Manual" && azapi_resource.this.body.properties.clusterCodeVersion == var.cluster_code_version && azapi_resource.this.body.properties.vmImage == "Linux" && azapi_resource.this.body.properties.vmssZonalUpgradeMode == "Parallel"
    error_message = "Runtime version, OS image, and zonal upgrade settings must be mapped."
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.nodeTypes) == 2 && azapi_resource.this.body.properties.nodeTypes[0].applicationPorts.startPort == 20000 && azapi_resource.this.body.properties.nodeTypes[0].ephemeralPorts.endPort == 65534 && azapi_resource.this.body.properties.nodeTypes[0].capacities.Memory == "8192" && azapi_resource.this.body.properties.nodeTypes[1].isStateless
    error_message = "Multiple node types, port ranges, capacities, and stateless configuration must be mapped."
  }

  assert {
    condition     = azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.timeouts.create == "1h" && azapi_resource.this.timeouts.delete == "30m"
    error_message = "Consumer retry and operation timeouts must be applied to the resource."
  }

  assert {
    condition     = azapi_resource.this.body.properties.reverseProxyCertificate.thumbprint == var.reverse_proxy_certificate.thumbprint && azapi_resource.this.body.properties.reverseProxyCertificate.thumbprintSecondary == var.reverse_proxy_certificate.thumbprint_secondary && azapi_resource.this.body.properties.reverseProxyCertificate.x509StoreName == "My" && !contains(keys(azapi_resource.this.body.properties), "reverseProxyCertificateCommonNames")
    error_message = "Reverse-proxy thumbprints must map to their dedicated certificate object, with the default store and no common-name object."
  }

  assert {
    condition     = azapi_resource.this.body.properties.upgradeDescription.forceRestart && azapi_resource.this.body.properties.upgradeDescription.healthCheckRetryTimeout == "00:30:00" && azapi_resource.this.body.properties.upgradeDescription.healthCheckStableDuration == "00:02:00" && azapi_resource.this.body.properties.upgradeDescription.healthCheckWaitDuration == "00:00:45" && azapi_resource.this.body.properties.upgradeDescription.upgradeDomainTimeout == "03:00:00" && azapi_resource.this.body.properties.upgradeDescription.upgradeReplicaSetCheckTimeout == "1.00:00:00.1234567" && azapi_resource.this.body.properties.upgradeDescription.upgradeTimeout == "1.12:00:00"
    error_message = "Every restart and duration override must map to the ARM upgrade description without changing TimeSpan strings."
  }

  assert {
    condition     = azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyApplications == 10 && azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyNodes == 20 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentDeltaUnhealthyApplications == 30 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentDeltaUnhealthyNodes == 40 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentUpgradeDomainDeltaUnhealthyNodes == 50
    error_message = "All cluster and delta health thresholds must map to the corresponding ARM percentage properties."
  }
}

run "reverse_proxy_common_names" {
  command = apply

  variables {
    reverse_proxy_certificate_common_names = {
      common_names = [
        {
          certificate_common_name       = "proxy.example.com"
          certificate_issuer_thumbprint = "5123456789012345678901234567890123456789"
        },
        {
          certificate_common_name       = "proxy-next.example.com"
          certificate_issuer_thumbprint = "6123456789012345678901234567890123456789"
        },
      ]
      x509_store_name = "TrustedPeople"
    }
    node_types = {
      primary = {
        name                        = "primary"
        is_primary                  = true
        vm_instance_count           = 5
        reverse_proxy_endpoint_port = 19081
      }
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.reverseProxyCertificateCommonNames.x509StoreName == "TrustedPeople" && length(azapi_resource.this.body.properties.reverseProxyCertificateCommonNames.commonNames) == 2 && azapi_resource.this.body.properties.reverseProxyCertificateCommonNames.commonNames[0].certificateCommonName == "proxy.example.com" && azapi_resource.this.body.properties.reverseProxyCertificateCommonNames.commonNames[1].certificateIssuerThumbprint == "6123456789012345678901234567890123456789" && !contains(keys(azapi_resource.this.body.properties), "reverseProxyCertificate")
    error_message = "Reverse-proxy common names, issuer thumbprints, and the custom store must be mapped independently of the cluster server certificate."
  }
}

run "upgrade_policy_defaults" {
  command = apply

  variables {
    upgrade_policy = {}
  }

  assert {
    condition     = !azapi_resource.this.body.properties.upgradeDescription.forceRestart && azapi_resource.this.body.properties.upgradeDescription.healthCheckRetryTimeout == "00:45:00" && azapi_resource.this.body.properties.upgradeDescription.healthCheckStableDuration == "00:01:00" && azapi_resource.this.body.properties.upgradeDescription.healthCheckWaitDuration == "00:00:30" && azapi_resource.this.body.properties.upgradeDescription.upgradeDomainTimeout == "02:00:00" && azapi_resource.this.body.properties.upgradeDescription.upgradeReplicaSetCheckTimeout == "10675199.02:48:05.4775807" && azapi_resource.this.body.properties.upgradeDescription.upgradeTimeout == "12:00:00"
    error_message = "An empty upgrade policy must supply all ARM-required durations with the documented defaults."
  }

  assert {
    condition     = azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyApplications == 0 && azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyNodes == 0 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy == null
    error_message = "The required health policy must default to zero thresholds, with no delta health policy configured."
  }
}

run "upgrade_policy_percentage_boundaries" {
  command = apply

  variables {
    upgrade_policy = {
      health_policy = {
        max_unhealthy_applications_percent = 100
        max_unhealthy_nodes_percent        = 0
      }
      delta_health_policy = {}
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyApplications == 100 && azapi_resource.this.body.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyNodes == 0 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentDeltaUnhealthyApplications == 0 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentDeltaUnhealthyNodes == 0 && azapi_resource.this.body.properties.upgradeDescription.deltaHealthPolicy.maxPercentUpgradeDomainDeltaUnhealthyNodes == 0
    error_message = "Health percentage boundaries must be accepted and an empty delta policy must default all required thresholds to zero."
  }
}

run "api_version_override" {
  command = apply

  variables {
    resource_types = {
      servicefabric_clusters = "Microsoft.ServiceFabric/clusters@2020-03-01"
    }
  }

  assert {
    condition     = azapi_resource.this.type == var.resource_types.servicefabric_clusters
    error_message = "The resource type must come from the consumer's API-version override."
  }
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "missing_primary_node" {
  command = plan

  variables {
    node_types = {}
  }

  expect_failures = [var.node_types]
}

run "invalid_node_ports" {
  command = plan

  variables {
    node_types = {
      primary = {
        name                            = "primary"
        is_primary                      = true
        vm_instance_count               = 5
        client_connection_endpoint_port = 65536
        application_ports               = { start_port = 30000, end_port = 20000 }
      }
    }
  }

  expect_failures = [var.node_types]
}

run "insufficient_primary_instances" {
  command = plan

  variables {
    node_types = {
      primary = {
        name              = "primary"
        is_primary        = true
        vm_instance_count = 4
      }
    }
  }

  expect_failures = [var.reliability_level]
}

run "multiple_primary_nodes" {
  command = plan

  variables {
    node_types = {
      primary = {
        name              = "primary"
        is_primary        = true
        vm_instance_count = 5
      }
      other = {
        name              = "other"
        is_primary        = true
        vm_instance_count = 5
      }
    }
  }

  expect_failures = [var.node_types]
}

run "missing_server_certificate" {
  command = plan

  variables {
    certificate = null
  }

  expect_failures = [var.certificate]
}

run "conflicting_server_certificates" {
  command = plan

  variables {
    certificate_common_names = {
      common_names = [{
        certificate_common_name       = "sf-test.example.com"
        certificate_issuer_thumbprint = "0123456789012345678901234567890123456789"
      }]
    }
  }

  expect_failures = [var.certificate]
}

run "manual_upgrade_requires_version" {
  command = plan

  variables {
    upgrade_mode = "Manual"
  }

  expect_failures = [var.cluster_code_version]
}

run "multi_zone_requires_upgrade_mode" {
  command = plan

  variables {
    node_types = {
      primary = {
        name                        = "primary"
        is_primary                  = true
        vm_instance_count           = 9
        multiple_availability_zones = true
      }
    }
  }

  expect_failures = [var.vmss_zonal_upgrade_mode]
}

run "conflicting_reverse_proxy_certificates" {
  command = plan

  variables {
    reverse_proxy_certificate = {
      thumbprint = "3123456789012345678901234567890123456789"
    }
    reverse_proxy_certificate_common_names = {
      common_names = [{
        certificate_common_name       = "proxy.example.com"
        certificate_issuer_thumbprint = "5123456789012345678901234567890123456789"
      }]
    }
  }

  expect_failures = [var.reverse_proxy_certificate]
}

run "empty_reverse_proxy_common_names" {
  command = plan

  variables {
    reverse_proxy_certificate_common_names = {
      common_names = []
    }
  }

  expect_failures = [var.reverse_proxy_certificate_common_names]
}

run "invalid_upgrade_duration_format" {
  command = plan

  variables {
    upgrade_policy = {
      upgrade_timeout = "12h"
    }
  }

  expect_failures = [var.upgrade_policy]
}

run "invalid_upgrade_duration_components" {
  command = plan

  variables {
    upgrade_policy = {
      health_check_wait_duration = "00:60:00"
    }
  }

  expect_failures = [var.upgrade_policy]
}

run "invalid_upgrade_health_percentage" {
  command = plan

  variables {
    upgrade_policy = {
      health_policy = {
        max_unhealthy_nodes_percent = 101
      }
    }
  }

  expect_failures = [var.upgrade_policy]
}

run "invalid_upgrade_delta_percentage" {
  command = plan

  variables {
    upgrade_policy = {
      delta_health_policy = {
        max_delta_unhealthy_applications_percent         = -1
        max_upgrade_domain_delta_unhealthy_nodes_percent = 0.5
      }
    }
  }

  expect_failures = [var.upgrade_policy]
}
