data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = local.settings.location
  name                   = "rg-${local.name}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = var.resource_types.resources_resource_groups
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) == 0 ? null : var.ignore_body_changes.resources_resource_groups
  response_export_values = []
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "vault" {
  location  = local.settings.location
  name      = "kv-${local.name}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.keyvault_vaults
  body = {
    properties = {
      tenantId                  = data.azapi_client_config.current.tenant_id
      sku                       = { family = "A", name = "standard" }
      enabledForDeployment      = true
      enableRbacAuthorization   = false
      enableSoftDelete          = true
      softDeleteRetentionInDays = 7
      publicNetworkAccess       = "Disabled"
      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Deny"
        ipRules             = []
        virtualNetworkRules = []
      }
      accessPolicies = [{
        tenantId = data.azapi_client_config.current.tenant_id
        objectId = data.azapi_client_config.current.object_id
        permissions = {
          secrets = ["get", "set", "delete"]
        }
      }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.keyvault_vaults) == 0 ? null : var.ignore_body_changes.keyvault_vaults
  response_export_values = []
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource_action" "certificate_secret" {
  method      = "PUT"
  resource_id = "${azapi_resource.vault.id}/secrets/cluster-certificate"
  type        = var.resource_types.keyvault_vaults_secrets
  body = {
    tags = { purpose = local.tags.purpose }
    properties = {
      contentType = "application/json"
      attributes  = { enabled = true }
    }
  }
  response_export_values = ["properties.secretUriWithVersion"]
  retry                  = var.retry
  sensitive_body = {
    properties = {
      value = local.secrets.certificate_secret
    }
  }
  sensitive_body_version = {
    "properties.value" = local.settings.certificate_thumbprint
  }
  when = "apply"

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "network_security_group" {
  location  = local.settings.location
  name      = "nsg-${local.name}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_network_security_groups
  body = {
    properties = {
      securityRules = [{
        name = "ManagementFromTestRunner"
        properties = {
          priority                 = 100
          access                   = "Allow"
          direction                = "Inbound"
          protocol                 = "Tcp"
          sourceAddressPrefix      = local.settings.management_source_prefix
          sourcePortRange          = "*"
          destinationAddressPrefix = "*"
          destinationPortRanges    = ["19000", "19080", "19081"]
        }
      }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_network_security_groups) == 0 ? null : var.ignore_body_changes.network_network_security_groups
  response_export_values = []
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "virtual_network" {
  location  = local.settings.location
  name      = "vnet-${local.name}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_virtual_networks
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.40.0.0/16"] }
      subnets = [{
        name = "nodes"
        properties = {
          addressPrefix        = "10.40.0.0/24"
          networkSecurityGroup = { id = azapi_resource.network_security_group.id }
        }
      }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_virtual_networks) == 0 ? null : var.ignore_body_changes.network_virtual_networks
  response_export_values = []
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "public_ip" {
  location  = local.settings.location
  name      = "pip-${local.name}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_public_ip_addresses
  body = {
    sku = { name = "Standard" }
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
      dnsSettings              = { domainNameLabel = local.name }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_public_ip_addresses) == 0 ? null : var.ignore_body_changes.network_public_ip_addresses
  response_export_values = ["properties.dnsSettings.fqdn"]
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "load_balancer" {
  location  = local.settings.location
  name      = "lb-${local.name}"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_load_balancers
  body = {
    sku = { name = "Standard" }
    properties = {
      frontendIPConfigurations = [{
        name       = "public"
        properties = { publicIPAddress = { id = azapi_resource.public_ip.id } }
      }]
      backendAddressPools = [{ name = "nodes" }]
      probes = [{
        name = "gateway"
        properties = {
          protocol          = "Tcp"
          port              = 19080
          intervalInSeconds = 5
          numberOfProbes    = 2
        }
      }]
      loadBalancingRules = [
        for port in [19000, 19080, 19081] : {
          name = "tcp-${port}"
          properties = {
            protocol                = "Tcp"
            frontendPort            = port
            backendPort             = port
            enableFloatingIP        = false
            disableOutboundSnat     = true
            idleTimeoutInMinutes    = 4
            frontendIPConfiguration = { id = "${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-${local.name}/frontendIPConfigurations/public" }
            backendAddressPool      = { id = "${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-${local.name}/backendAddressPools/nodes" }
            probe                   = { id = "${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-${local.name}/probes/gateway" }
          }
        }
      ]
      outboundRules = [{
        name = "outbound"
        properties = {
          protocol               = "All"
          allocatedOutboundPorts = 1024
          idleTimeoutInMinutes   = 4
          enableTcpReset         = true
          backendAddressPool     = { id = "${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-${local.name}/backendAddressPools/nodes" }
          frontendIPConfigurations = [{
            id = "${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-${local.name}/frontendIPConfigurations/public"
          }]
        }
      }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_load_balancers) == 0 ? null : var.ignore_body_changes.network_load_balancers
  response_export_values = []
  retry                  = var.retry
  tags                   = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

module "cluster" {
  source = "../../../"

  location            = local.settings.location
  management_endpoint = "https://${azapi_resource.public_ip.output.properties.dnsSettings.fqdn}:19080"
  name                = local.name
  node_types = {
    primary = {
      name                        = "primary"
      is_primary                  = true
      vm_instance_count           = 3
      durability_level            = "Bronze"
      reverse_proxy_endpoint_port = 19081
      application_ports           = { start_port = 20000, end_port = 30000 }
      ephemeral_ports             = { start_port = 49152, end_port = 65534 }
    }
  }
  parent_id                = azapi_resource.resource_group.id
  add_on_features          = var.configure_optional_features ? ["DnsService"] : []
  certificate              = var.certificate_mode == "thumbprint" ? { thumbprint = local.settings.certificate_thumbprint } : null
  certificate_common_names = var.certificate_mode == "common_name" ? local.common_names : null
  client_certificate_thumbprints = [{
    certificate_thumbprint = local.settings.certificate_thumbprint
    is_admin               = true
  }]
  enable_telemetry            = var.enable_telemetry
  event_store_service_enabled = var.configure_optional_features
  fabric_settings = {
    Security = { ClusterProtectionLevel = "EncryptAndSign" }
  }
  reliability_level         = "Bronze"
  retry                     = var.retry
  reverse_proxy_certificate = var.configure_optional_features && var.certificate_mode == "thumbprint" ? { thumbprint = local.settings.certificate_thumbprint } : null
  reverse_proxy_certificate_common_names = var.configure_optional_features && var.certificate_mode == "common_name" ? {
    common_names = [{
      certificate_common_name = local.settings.certificate_common_name
    }]
  } : null
  tags     = local.tags
  timeouts = var.timeouts
  upgrade_policy = var.configure_optional_features ? {
    health_check_retry_timeout        = "00:30:00"
    health_check_stable_duration      = "00:01:00"
    health_check_wait_duration        = "00:00:30"
    upgrade_domain_timeout            = "02:00:00"
    upgrade_replica_set_check_timeout = "00:20:00"
    upgrade_timeout                   = "06:00:00"
    health_policy                     = {}
    delta_health_policy               = {}
  } : null
}

resource "azapi_resource" "scale_set" {
  location  = local.settings.location
  name      = "primary"
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.compute_virtual_machine_scale_sets
  body = {
    sku = {
      name     = local.settings.vm_sku
      tier     = "Standard"
      capacity = 3
    }
    properties = {
      overprovision        = false
      singlePlacementGroup = true
      upgradePolicy        = { mode = "Automatic" }
      virtualMachineProfile = {
        storageProfile = {
          imageReference = {
            publisher = "MicrosoftWindowsServer"
            offer     = "WindowsServer"
            sku       = "2022-datacenter-azure-edition"
            version   = "latest"
          }
          osDisk = {
            createOption = "FromImage"
            caching      = "ReadWrite"
            managedDisk  = { storageAccountType = "Standard_LRS" }
          }
        }
        osProfile = {
          computerNamePrefix = "sfnode"
          adminUsername      = "avmtestadmin"
          windowsConfiguration = {
            provisionVMAgent       = true
            enableAutomaticUpdates = true
          }
          secrets = [{
            sourceVault = { id = azapi_resource.vault.id }
            vaultCertificates = [{
              certificateStore = "My"
              certificateUrl   = azapi_resource_action.certificate_secret.output.properties.secretUriWithVersion
            }]
          }]
        }
        networkProfile = {
          networkInterfaceConfigurations = [{
            name = "nic"
            properties = {
              primary = true
              ipConfigurations = [{
                name = "ip"
                properties = {
                  primary                         = true
                  subnet                          = { id = "${azapi_resource.virtual_network.id}/subnets/nodes" }
                  loadBalancerBackendAddressPools = [{ id = "${azapi_resource.load_balancer.id}/backendAddressPools/nodes" }]
                }
              }]
            }
          }]
        }
        extensionProfile = {
          extensions = [{
            name = "ServiceFabricNode"
            properties = {
              publisher               = "Microsoft.Azure.ServiceFabric"
              type                    = "ServiceFabricNode"
              typeHandlerVersion      = "1.1"
              autoUpgradeMinorVersion = true
              settings = {
                clusterEndpoint   = module.cluster.cluster_endpoint
                nodeTypeRef       = "primary"
                dataPath          = "C:\\SvcFab"
                durabilityLevel   = "Bronze"
                nicPrefixOverride = "10.40.0.0/24"
                certificate = {
                  thumbprint    = local.settings.certificate_thumbprint
                  x509StoreName = "My"
                }
              }
            }
          }]
        }
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.compute_virtual_machine_scale_sets) == 0 ? null : var.ignore_body_changes.compute_virtual_machine_scale_sets
  response_export_values = ["properties.provisioningState"]
  retry                  = var.retry
  sensitive_body = {
    properties = {
      virtualMachineProfile = {
        osProfile = { adminPassword = local.secrets.admin_password }
      }
    }
  }
  sensitive_body_version = {
    "properties.virtualMachineProfile.osProfile.adminPassword" = local.settings.name_prefix
  }
  tags = local.tags

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "terraform_data" "validation_revision" {
  triggers_replace = var.validation_revision
}

resource "azapi_resource_action" "runtime_health" {
  action      = "runCommand"
  method      = "POST"
  resource_id = "${azapi_resource.scale_set.id}/virtualMachines/0"
  type        = var.resource_types.compute_virtual_machine_scale_sets_virtual_machines
  body = {
    commandId = "RunPowerShellScript"
    script = split("\n", <<-POWERSHELL
      $ErrorActionPreference = 'Stop'
      $ModulePath = Get-ChildItem "$env:ProgramFiles\Microsoft Service Fabric" -Filter ServiceFabric.psd1 -Recurse | Select-Object -First 1 -ExpandProperty FullName
      if (-not $ModulePath) { throw 'Service Fabric PowerShell module was not installed.' }
      $NativeLibrary = Get-ChildItem "$env:ProgramFiles\Microsoft Service Fabric" -Filter FabricCommon.dll -Recurse | Select-Object -First 1 -ExpandProperty FullName
      if (-not $NativeLibrary) { throw 'The Service Fabric native client library was not installed.' }
      # Run Command inherits the VM agent's pre-install PATH.
      $env:PATH = "$(Split-Path $NativeLibrary -Parent);$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$env:PATH"
      Import-Module $ModulePath
      $RequireDnsService = ${var.configure_optional_features ? "$true" : "$false"}
      $Deadline = (Get-Date).AddMinutes(20)
      $LastFailure = 'The cluster has not yet been queried.'
      do {
        try {
          Connect-ServiceFabricCluster -ConnectionEndpoint 'localhost:19000' -X509Credential -ServerCertThumbprint '${local.settings.certificate_thumbprint}' -FindType FindByThumbprint -FindValue '${local.settings.certificate_thumbprint}' -StoreLocation LocalMachine -StoreName My -TimeoutSec 30 | Out-Null
          $Nodes = @(Get-ServiceFabricNode -TimeoutSec 30)
          $Health = Get-ServiceFabricClusterHealth -TimeoutSec 30
          $DnsServiceHealthy = -not $RequireDnsService
          if ($RequireDnsService) {
            $DnsServiceHealth = Get-ServiceFabricServiceHealth -ServiceName 'fabric:/System/DnsService' -TimeoutSec 30
            $DnsServiceHealthy = $DnsServiceHealth.AggregatedHealthState -eq 'Ok'
          }
          if ($Nodes.Count -eq 3 -and @($Nodes | Where-Object { $_.NodeStatus -ne 'Up' }).Count -eq 0 -and $Health.AggregatedHealthState -eq 'Ok' -and $DnsServiceHealthy) {
            if ($RequireDnsService) { Write-Output 'AVM_DNS_OK_${var.validation_revision}' }
            Write-Output 'AVM_HEALTH_OK_${var.validation_revision}'
            exit 0
          }
          $LastFailure = "Nodes: $($Nodes.Count); health: $($Health.AggregatedHealthState); DNS required: $RequireDnsService; DNS healthy: $DnsServiceHealthy."
        } catch {
          if ($_.Exception.Message -like '*Unable to load DLL*') { throw }
          $LastFailure = $_.Exception.Message
        }
        Write-Output "Waiting for cluster readiness: $LastFailure"
        Start-Sleep -Seconds 20
      } while ((Get-Date) -lt $Deadline)
      throw "Service Fabric failed to become healthy within 20 minutes. $LastFailure"
    POWERSHELL
    )
  }
  response_export_values = ["value"]
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.validation_revision]

    postcondition {
      condition     = anytrue([for status in self.output.value : status.code == "ComponentStatus/StdOut/succeeded" && strcontains(status.message, "AVM_HEALTH_OK_${var.validation_revision}")])
      error_message = "The guest health check must report three Up nodes, an Ok aggregate cluster health state, and a healthy DNS service when enabled. Guest diagnostics: ${join("\n", [for status in self.output.value : "${status.code}: ${status.message}"])}"
    }
  }
}

data "azapi_resource" "observed_cluster" {
  resource_id = module.cluster.resource_id
  type        = "Microsoft.ServiceFabric/clusters@2021-06-01"
  response_export_values = [
    "properties.clusterState",
    "properties.clusterId",
    "properties.certificate",
    "properties.certificateCommonNames",
    "properties.reverseProxyCertificate",
    "properties.reverseProxyCertificateCommonNames",
    "properties.upgradeDescription",
    "properties.nodeTypes",
    "properties.reliabilityLevel",
    "properties.eventStoreServiceEnabled",
    "tags",
  ]

  depends_on = [azapi_resource_action.runtime_health]
}
