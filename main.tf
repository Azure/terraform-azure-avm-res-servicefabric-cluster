resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.servicefabric_clusters
  body = {
    properties = { for property, value in {
      managementEndpoint   = var.management_endpoint
      reliabilityLevel     = var.reliability_level
      upgradeMode          = var.upgrade_mode
      clusterCodeVersion   = var.cluster_code_version
      vmImage              = var.vm_image
      sfZonalUpgradeMode   = var.sf_zonal_upgrade_mode
      vmssZonalUpgradeMode = var.vmss_zonal_upgrade_mode
      nodeTypes = [
        for node_type in values(var.node_types) : { for property, value in {
          name                         = node_type.name
          clientConnectionEndpointPort = node_type.client_connection_endpoint_port
          httpGatewayEndpointPort      = node_type.http_gateway_endpoint_port
          isPrimary                    = node_type.is_primary
          vmInstanceCount              = node_type.vm_instance_count
          durabilityLevel              = node_type.durability_level
          capacities                   = node_type.capacities
          placementProperties          = node_type.placement_properties
          reverseProxyEndpointPort     = node_type.reverse_proxy_endpoint_port
          isStateless                  = node_type.is_stateless
          multipleAvailabilityZones    = node_type.multiple_availability_zones
          applicationPorts = node_type.application_ports == null ? null : {
            startPort = node_type.application_ports.start_port
            endPort   = node_type.application_ports.end_port
          }
          ephemeralPorts = node_type.ephemeral_ports == null ? null : {
            startPort = node_type.ephemeral_ports.start_port
            endPort   = node_type.ephemeral_ports.end_port
          }
        } : property => value if value != null }
      ]
      certificate = var.certificate == null ? null : {
        thumbprint          = var.certificate.thumbprint
        thumbprintSecondary = var.certificate.thumbprint_secondary
        x509StoreName       = var.certificate.x509_store_name
      }
      certificateCommonNames = var.certificate_common_names == null ? null : {
        commonNames = [
          for certificate in var.certificate_common_names.common_names : {
            certificateCommonName       = certificate.certificate_common_name
            certificateIssuerThumbprint = certificate.certificate_issuer_thumbprint
          }
        ]
        x509StoreName = var.certificate_common_names.x509_store_name
      }
      reverseProxyCertificate = var.reverse_proxy_certificate == null ? null : {
        thumbprint          = var.reverse_proxy_certificate.thumbprint
        thumbprintSecondary = var.reverse_proxy_certificate.thumbprint_secondary
        x509StoreName       = var.reverse_proxy_certificate.x509_store_name
      }
      reverseProxyCertificateCommonNames = var.reverse_proxy_certificate_common_names == null ? null : {
        commonNames = [
          for certificate in var.reverse_proxy_certificate_common_names.common_names : {
            certificateCommonName       = certificate.certificate_common_name
            certificateIssuerThumbprint = certificate.certificate_issuer_thumbprint
          }
        ]
        x509StoreName = var.reverse_proxy_certificate_common_names.x509_store_name
      }
      upgradeDescription = var.upgrade_policy == null ? null : {
        forceRestart                  = var.upgrade_policy.force_restart_enabled
        healthCheckRetryTimeout       = var.upgrade_policy.health_check_retry_timeout
        healthCheckStableDuration     = var.upgrade_policy.health_check_stable_duration
        healthCheckWaitDuration       = var.upgrade_policy.health_check_wait_duration
        upgradeDomainTimeout          = var.upgrade_policy.upgrade_domain_timeout
        upgradeReplicaSetCheckTimeout = var.upgrade_policy.upgrade_replica_set_check_timeout
        upgradeTimeout                = var.upgrade_policy.upgrade_timeout
        healthPolicy = {
          maxPercentUnhealthyApplications = var.upgrade_policy.health_policy.max_unhealthy_applications_percent
          maxPercentUnhealthyNodes        = var.upgrade_policy.health_policy.max_unhealthy_nodes_percent
        }
        deltaHealthPolicy = var.upgrade_policy.delta_health_policy == null ? null : {
          maxPercentDeltaUnhealthyApplications       = var.upgrade_policy.delta_health_policy.max_delta_unhealthy_applications_percent
          maxPercentDeltaUnhealthyNodes              = var.upgrade_policy.delta_health_policy.max_delta_unhealthy_nodes_percent
          maxPercentUpgradeDomainDeltaUnhealthyNodes = var.upgrade_policy.delta_health_policy.max_upgrade_domain_delta_unhealthy_nodes_percent
        }
      }
      clientCertificateThumbprints = [
        for certificate in var.client_certificate_thumbprints : {
          certificateThumbprint = certificate.certificate_thumbprint
          isAdmin               = certificate.is_admin
        }
      ]
      clientCertificateCommonNames = [
        for certificate in var.client_certificate_common_names : {
          certificateCommonName       = certificate.certificate_common_name
          certificateIssuerThumbprint = certificate.certificate_issuer_thumbprint
          isAdmin                     = certificate.is_admin
        }
      ]
      azureActiveDirectory = var.azure_active_directory == null ? null : {
        tenantId           = var.azure_active_directory.tenant_id
        clusterApplication = var.azure_active_directory.cluster_application
        clientApplication  = var.azure_active_directory.client_application
      }
      diagnosticsStorageAccountConfig = var.diagnostics_storage_account_config == null ? null : {
        storageAccountName       = var.diagnostics_storage_account_config.storage_account_name
        protectedAccountKeyName  = var.diagnostics_storage_account_config.protected_account_key_name
        protectedAccountKeyName2 = var.diagnostics_storage_account_config.protected_account_key_name_secondary
        blobEndpoint             = var.diagnostics_storage_account_config.blob_endpoint
        queueEndpoint            = var.diagnostics_storage_account_config.queue_endpoint
        tableEndpoint            = var.diagnostics_storage_account_config.table_endpoint
      }
      fabricSettings = [
        for section, parameters in var.fabric_settings : {
          name = section
          parameters = [
            for name, value in parameters : {
              name  = name
              value = value
            }
          ]
        }
      ]
      addOnFeatures            = var.add_on_features
      eventStoreServiceEnabled = var.event_store_service_enabled
    } : property => value if value != null }
  }
  ignore_body_changes  = length(var.ignore_body_changes.servicefabric_clusters) > 0 ? var.ignore_body_changes.servicefabric_clusters : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.managementEndpoint",
    "properties.nodeTypes[?isPrimary].name",
    "properties.vmImage",
  ]
  response_export_values = [
    "properties.clusterEndpoint",
    "properties.clusterId",
  ]
  retry = var.retry
  tags  = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
