variable "location" {
  type        = string
  description = "The Azure region where the Service Fabric cluster will be created."
  nullable    = false
}

variable "management_endpoint" {
  type        = string
  description = "The HTTP or HTTPS management endpoint of the cluster, including the gateway port. The consumer supplies the corresponding load balancer or DNS endpoint. Changing this value replaces the cluster."
  nullable    = false

  validation {
    condition     = can(regex("^https?://[^/[:space:]]+", var.management_endpoint))
    error_message = "`management_endpoint` must be an HTTP or HTTPS URL."
  }
}

variable "name" {
  type        = string
  description = "The name of the Service Fabric cluster."
  nullable    = false

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "The cluster name must not be empty."
  }
}

variable "node_types" {
  type = map(object({
    name                            = string
    is_primary                      = bool
    vm_instance_count               = number
    client_connection_endpoint_port = optional(number, 19000)
    http_gateway_endpoint_port      = optional(number, 19080)
    durability_level                = optional(string, "Bronze")
    capacities                      = optional(map(string), {})
    placement_properties            = optional(map(string), {})
    reverse_proxy_endpoint_port     = optional(number)
    is_stateless                    = optional(bool)
    multiple_availability_zones     = optional(bool)
    application_ports = optional(object({
      start_port = number
      end_port   = number
    }))
    ephemeral_ports = optional(object({
      start_port = number
      end_port   = number
    }))
  }))
  description = <<DESCRIPTION
Node type definitions keyed by a caller-chosen key. These configure the cluster only; corresponding VM scale sets and Service Fabric VM extensions must be supplied separately.

- `name` - Node type name, matching the node type configured on the VM scale set extension.
- `is_primary` - Whether this node type hosts system services. Exactly one must be primary.
- `vm_instance_count` - Number of corresponding VM instances. Primary node types must have at least one instance.
- `client_connection_endpoint_port` - Client connection port, defaulting to 19000.
- `http_gateway_endpoint_port` - HTTP management gateway port, defaulting to 19080.
- `durability_level` - Bronze, Silver, or Gold infrastructure durability.
- `capacities` - Node capacity name/value pairs.
- `placement_properties` - Node placement property name/value pairs.
- `reverse_proxy_endpoint_port` - Optional reverse proxy port.
- `is_stateless` - Optional flag for stateless-only workloads. Omitted when null.
- `multiple_availability_zones` - Optional flag for spanning availability zones. Omitted when null.
- `application_ports` - Optional application port range with inclusive `start_port` and `end_port`.
- `ephemeral_ports` - Optional ephemeral port range with inclusive `start_port` and `end_port`.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length([for node_type in values(var.node_types) : node_type if node_type.is_primary]) == 1
    error_message = "`node_types` must contain exactly one primary node type."
  }
  validation {
    condition = alltrue([
      for node_type in values(var.node_types) :
      length(trimspace(node_type.name)) > 0 &&
      node_type.vm_instance_count >= (node_type.is_primary ? 1 : 0) &&
      node_type.vm_instance_count == floor(node_type.vm_instance_count) &&
      contains(["Bronze", "Silver", "Gold"], node_type.durability_level) &&
      !(node_type.is_primary && node_type.is_stateless == true)
    ]) && length(distinct([for node_type in values(var.node_types) : node_type.name])) == length(var.node_types)
    error_message = "Node type names must be non-empty and unique, instance counts must be non-negative integers (positive for the primary), durability must be Bronze, Silver, or Gold, and the primary cannot be stateless."
  }
  validation {
    condition = alltrue(flatten([
      for node_type in values(var.node_types) : [
        for port in [node_type.client_connection_endpoint_port, node_type.http_gateway_endpoint_port, node_type.reverse_proxy_endpoint_port] :
        port == null ? true : port >= 1 && port <= 65535 && port == floor(port)
      ]
      ])) && alltrue(flatten([
      for node_type in values(var.node_types) : [
        for ports in [node_type.application_ports, node_type.ephemeral_ports] :
        ports == null ? true : ports.start_port >= 1 && ports.end_port <= 65535 && ports.start_port <= ports.end_port && ports.start_port == floor(ports.start_port) && ports.end_port == floor(ports.end_port)
      ]
    ]))
    error_message = "Ports must be integers between 1 and 65535, and port ranges must start at or before their end."
  }
}

variable "parent_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the existing resource group into which the Service Fabric cluster will be deployed."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource group resource ID."
  }
}

variable "add_on_features" {
  type        = set(string)
  default     = []
  description = "Optional cluster add-on features, such as DnsService, RepairManager, and BackupRestoreService."
  nullable    = false
}

variable "azure_active_directory" {
  type = object({
    tenant_id           = string
    cluster_application = string
    client_application  = string
  })
  default     = null
  description = "Optional Microsoft Entra authentication configuration: `tenant_id` identifies the tenant, `cluster_application` the server application ID, and `client_application` the client application ID."
}

variable "certificate" {
  type = object({
    thumbprint           = string
    thumbprint_secondary = optional(string)
    x509_store_name      = optional(string, "My")
  })
  default     = null
  description = <<DESCRIPTION
Cluster server certificate referenced by thumbprint. Supply either this object or `certificate_common_names` to secure the cluster.

- `thumbprint` - Primary certificate thumbprint.
- `thumbprint_secondary` - Optional secondary thumbprint for certificate rotation.
- `x509_store_name` - Local certificate store, defaulting to My.
DESCRIPTION

  validation {
    condition     = (var.certificate != null) != (var.certificate_common_names != null)
    error_message = "Supply exactly one of `certificate` or `certificate_common_names` to secure the cluster."
  }
}

variable "certificate_common_names" {
  type = object({
    common_names = list(object({
      certificate_common_name       = string
      certificate_issuer_thumbprint = string
    }))
    x509_store_name = optional(string, "My")
  })
  default     = null
  description = <<DESCRIPTION
Cluster server certificates referenced by common name, as an alternative to `certificate`.

- `common_names` - Certificate entries containing `certificate_common_name` and `certificate_issuer_thumbprint`.
- `x509_store_name` - Local certificate store, defaulting to My.
DESCRIPTION

  validation {
    condition     = var.certificate_common_names == null ? true : length(var.certificate_common_names.common_names) > 0
    error_message = "`certificate_common_names.common_names` must contain at least one certificate."
  }
}

variable "client_certificate_common_names" {
  type = list(object({
    certificate_common_name       = string
    certificate_issuer_thumbprint = string
    is_admin                      = bool
  }))
  default     = []
  description = "Client certificates allowed to manage the cluster by common name. Each entry supplies `certificate_common_name`, `certificate_issuer_thumbprint`, and `is_admin` (false grants read-only access)."
  nullable    = false
}

variable "client_certificate_thumbprints" {
  type = list(object({
    certificate_thumbprint = string
    is_admin               = bool
  }))
  default     = []
  description = "Client certificates allowed to manage the cluster. Each entry supplies `certificate_thumbprint` and `is_admin` (false grants read-only access)."
  nullable    = false
}

variable "cluster_code_version" {
  type        = string
  default     = null
  description = "Service Fabric runtime version to deploy when `upgrade_mode` is Manual. Leave null for Automatic upgrades."

  validation {
    condition     = var.upgrade_mode == "Manual" ? (var.cluster_code_version == null ? false : length(trimspace(var.cluster_code_version)) > 0) : var.cluster_code_version == null
    error_message = "Supply a non-empty `cluster_code_version` for Manual upgrades and leave it null for Automatic upgrades."
  }
}

variable "diagnostics_storage_account_config" {
  type = object({
    storage_account_name                 = string
    protected_account_key_name           = string
    protected_account_key_name_secondary = optional(string)
    blob_endpoint                        = string
    queue_endpoint                       = string
    table_endpoint                       = string
  })
  default     = null
  description = <<DESCRIPTION
Optional existing storage account configuration for Service Fabric diagnostic logs. This does not create a storage account or an Azure Monitor diagnostic setting.

- `storage_account_name` - Existing storage account name.
- `protected_account_key_name` - Name of the protected primary account-key setting, not the account key itself.
- `protected_account_key_name_secondary` - Optional protected secondary account-key setting name.
- `blob_endpoint` - Storage blob endpoint.
- `queue_endpoint` - Storage queue endpoint.
- `table_endpoint` - Storage table endpoint.
DESCRIPTION
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "event_store_service_enabled" {
  type        = bool
  default     = false
  description = "Whether the Service Fabric EventStore service is enabled."
  nullable    = false
}

variable "fabric_settings" {
  type        = map(map(string))
  default     = {}
  description = "Custom Service Fabric configuration, keyed by section name, then parameter name, with string parameter values. Do not supply secrets in this input."
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    servicefabric_clusters = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore, using dot notation. Changes take effect only after apply. Ignored configuration is not sent to Azure until the path is removed.

- `servicefabric_clusters` - Paths ignored on the Service Fabric cluster.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for path in var.ignore_body_changes.servicefabric_clusters : length(trimspace(path)) > 0])
    error_message = "Ignored body paths must not be empty."
  }
}

variable "reliability_level" {
  type        = string
  default     = "Silver"
  description = "System service reliability level: None (1 replica), Bronze (3), Silver (5), Gold (7), or Platinum (9). Provision sufficient primary node instances for the selected level."
  nullable    = false

  validation {
    condition     = contains(["None", "Bronze", "Silver", "Gold", "Platinum"], var.reliability_level)
    error_message = "`reliability_level` must be None, Bronze, Silver, Gold, or Platinum."
  }
  validation {
    condition = contains(["None", "Bronze", "Silver", "Gold", "Platinum"], var.reliability_level) ? alltrue([
      for node_type in values(var.node_types) : node_type.vm_instance_count >= {
        None     = 1
        Bronze   = 3
        Silver   = 5
        Gold     = 7
        Platinum = 9
      }[var.reliability_level] if node_type.is_primary
    ]) : true
    error_message = "The primary node type must have at least 1, 3, 5, 7, or 9 instances for None, Bronze, Silver, Gold, or Platinum reliability respectively."
  }
}

variable "resource_types" {
  type = object({
    servicefabric_clusters = optional(string, "Microsoft.ServiceFabric/clusters@2021-06-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by this module.

- `servicefabric_clusters` - Resource type and API version for the Service Fabric cluster.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration for the cluster. Null uses the provider defaults.

- `error_message_regex` - Error-message patterns that trigger retries.
- `interval_seconds` - Initial retry interval in seconds.
- `max_interval_seconds` - Maximum retry interval in seconds.
DESCRIPTION
}

variable "reverse_proxy_certificate" {
  type = object({
    thumbprint           = string
    thumbprint_secondary = optional(string)
    x509_store_name      = optional(string, "My")
  })
  default     = null
  description = <<DESCRIPTION
Optional reverse-proxy server certificate referenced by thumbprint. Mutually exclusive with `reverse_proxy_certificate_common_names`. The certificate must be installed on the nodes; configure the reverse-proxy port separately in `node_types`.

- `thumbprint` - Primary reverse-proxy certificate thumbprint.
- `thumbprint_secondary` - Optional secondary thumbprint for certificate rotation.
- `x509_store_name` - Local certificate store, defaulting to My.
DESCRIPTION

  validation {
    condition     = var.reverse_proxy_certificate == null || var.reverse_proxy_certificate_common_names == null
    error_message = "Supply at most one of `reverse_proxy_certificate` or `reverse_proxy_certificate_common_names`."
  }
}

variable "reverse_proxy_certificate_common_names" {
  type = object({
    common_names = list(object({
      certificate_common_name       = string
      certificate_issuer_thumbprint = optional(string)
    }))
    x509_store_name = optional(string, "My")
  })
  default     = null
  description = <<DESCRIPTION
Optional reverse-proxy server certificates referenced by common name, as an alternative to `reverse_proxy_certificate`. Certificates must be installed on the nodes; configure the reverse-proxy port separately in `node_types`.

- `common_names` - Non-empty list of entries requiring `certificate_common_name`. `certificate_issuer_thumbprint` is optional; omit it because the current Azure API rejects issuer thumbprints on reverse-proxy certificates.
- `x509_store_name` - Local certificate store, defaulting to My.
DESCRIPTION

  validation {
    condition     = var.reverse_proxy_certificate_common_names == null ? true : length(var.reverse_proxy_certificate_common_names.common_names) > 0
    error_message = "`reverse_proxy_certificate_common_names.common_names` must contain at least one certificate."
  }
}

variable "sf_zonal_upgrade_mode" {
  type        = string
  default     = null
  description = "Optional Service Fabric upgrade-domain grouping for multi-zone node types: Parallel or Hierarchical."

  validation {
    condition     = var.sf_zonal_upgrade_mode == null ? true : contains(["Parallel", "Hierarchical"], var.sf_zonal_upgrade_mode)
    error_message = "`sf_zonal_upgrade_mode` must be Parallel, Hierarchical, or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to the Service Fabric cluster."
  nullable    = false
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Cluster operation timeouts expressed as Go duration strings, such as 30m or 1h. Null uses provider defaults.

- `create` - Create timeout.
- `read` - Read timeout.
- `update` - Update timeout.
- `delete` - Delete timeout.
DESCRIPTION
}

variable "upgrade_mode" {
  type        = string
  default     = "Automatic"
  description = "Runtime upgrade mode: Automatic or Manual. Manual requires `cluster_code_version`."
  nullable    = false

  validation {
    condition     = contains(["Automatic", "Manual"], var.upgrade_mode)
    error_message = "`upgrade_mode` must be Automatic or Manual."
  }
}

variable "upgrade_policy" {
  type = object({
    force_restart_enabled             = optional(bool, false)
    health_check_retry_timeout        = optional(string, "00:45:00")
    health_check_stable_duration      = optional(string, "00:01:00")
    health_check_wait_duration        = optional(string, "00:00:30")
    upgrade_domain_timeout            = optional(string, "02:00:00")
    upgrade_replica_set_check_timeout = optional(string, "10675199.02:48:05.4775807")
    upgrade_timeout                   = optional(string, "12:00:00")
    health_policy = optional(object({
      max_unhealthy_applications_percent = optional(number, 0)
      max_unhealthy_nodes_percent        = optional(number, 0)
    }), {})
    delta_health_policy = optional(object({
      max_delta_unhealthy_applications_percent         = optional(number, 0)
      max_delta_unhealthy_nodes_percent                = optional(number, 0)
      max_upgrade_domain_delta_unhealthy_nodes_percent = optional(number, 0)
    }))
  })
  default     = null
  description = <<DESCRIPTION
Optional cluster upgrade policy mapped to ARM `upgradeDescription`. Null omits the policy, preserving service defaults. Supplying an object applies the defaults below. Durations use non-negative `hh:mm:ss` or `d.hh:mm:ss.fffffff` TimeSpan strings, not Go duration strings used by `timeouts`; hours are 00-23, minutes and seconds 00-59, and fractional seconds have at most seven digits.

- `force_restart_enabled` - Restart processes even for dynamic configuration changes. Defaults to false.
- `health_check_retry_timeout` - Time to retry failed health checks before rollback. Defaults to 00:45:00.
- `health_check_stable_duration` - Time the cluster must remain healthy before proceeding. Defaults to 00:01:00.
- `health_check_wait_duration` - Delay before the initial health check after upgrading a domain. Defaults to 00:00:30.
- `upgrade_domain_timeout` - Maximum time for one upgrade domain. Defaults to 02:00:00.
- `upgrade_replica_set_check_timeout` - Maximum time to wait for replica-set safety per domain. Defaults to 10675199.02:48:05.4775807.
- `upgrade_timeout` - Maximum time for the whole upgrade. Defaults to 12:00:00.
- `health_policy` - Cluster health thresholds, defaulting to zero percent unhealthy.
- `health_policy.max_unhealthy_applications_percent` - Maximum unhealthy applications percentage, an integer from 0 to 100.
- `health_policy.max_unhealthy_nodes_percent` - Maximum unhealthy nodes percentage, an integer from 0 to 100.
- `delta_health_policy` - Optional thresholds for health degradation relative to the start of the upgrade. Omitted when null; its fields default to zero when supplied.
- `delta_health_policy.max_delta_unhealthy_applications_percent` - Maximum increase in unhealthy applications percentage, an integer from 0 to 100.
- `delta_health_policy.max_delta_unhealthy_nodes_percent` - Maximum increase in unhealthy nodes percentage, an integer from 0 to 100.
- `delta_health_policy.max_upgrade_domain_delta_unhealthy_nodes_percent` - Maximum increase in unhealthy nodes percentage within an upgrade domain, an integer from 0 to 100.
DESCRIPTION

  validation {
    condition = var.upgrade_policy == null ? true : alltrue([
      for duration in [
        var.upgrade_policy.health_check_retry_timeout,
        var.upgrade_policy.health_check_stable_duration,
        var.upgrade_policy.health_check_wait_duration,
        var.upgrade_policy.upgrade_domain_timeout,
        var.upgrade_policy.upgrade_replica_set_check_timeout,
        var.upgrade_policy.upgrade_timeout,
      ] : can(regex("^([0-9]+\\.)?([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\\.[0-9]{1,7})?$", duration))
    ])
    error_message = "Upgrade policy durations must use non-negative hh:mm:ss or d.hh:mm:ss.fffffff TimeSpan format with hours 00-23, minutes and seconds 00-59, and at most seven fractional digits."
  }
  validation {
    condition = var.upgrade_policy == null ? true : alltrue([
      for percentage in concat(
        values(var.upgrade_policy.health_policy),
        var.upgrade_policy.delta_health_policy == null ? [] : values(var.upgrade_policy.delta_health_policy)
      ) : percentage >= 0 && percentage <= 100 && percentage == floor(percentage)
    ])
    error_message = "Upgrade health-policy and delta-health-policy percentages must be integers between 0 and 100."
  }
}

variable "vm_image" {
  type        = string
  default     = "Windows"
  description = "Operating system image configured on the external VM scale sets, such as Windows or Linux. Changing this value replaces the cluster."
  nullable    = false
}

variable "vmss_zonal_upgrade_mode" {
  type        = string
  default     = null
  description = "VM scale set zonal upgrade mode: Parallel or Hierarchical. Required when any node type spans multiple availability zones."

  validation {
    condition     = var.vmss_zonal_upgrade_mode == null ? !anytrue([for node_type in values(var.node_types) : node_type.multiple_availability_zones == true]) : contains(["Parallel", "Hierarchical"], var.vmss_zonal_upgrade_mode)
    error_message = "`vmss_zonal_upgrade_mode` must be Parallel or Hierarchical when a node type spans multiple availability zones."
  }
}
