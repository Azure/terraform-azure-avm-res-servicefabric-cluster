output "resource_id" {
  description = "Resource ID of the real cluster under test."
  value       = module.cluster.resource_id
}

output "cluster_id" {
  description = "Azure-generated cluster identifier, used to detect accidental replacements."
  value       = module.cluster.cluster_id
}

output "cluster_endpoint" {
  description = "Service Fabric resource-provider endpoint used by the VM extension."
  value       = module.cluster.cluster_endpoint
}

output "management_endpoint" {
  description = "Certificate-authenticated HTTPS management endpoint."
  value       = module.cluster.management_endpoint
}

output "certificate_thumbprint" {
  description = "Public thumbprint of the test certificate installed on all nodes."
  value       = local.settings.certificate_thumbprint
}

output "certificate_common_name" {
  description = "Public subject common name of the test certificate."
  value       = local.settings.certificate_common_name
}

output "persisted_configuration" {
  description = "Fresh ARM read of the cluster settings and state after guest health verification."
  value       = data.azapi_resource.observed_cluster.output
}

output "vm_provisioning_state" {
  description = "Provisioning state returned by the real VM scale set."
  value       = azapi_resource.scale_set.output.properties.provisioningState
}

output "runtime_health_verified" {
  description = "Whether the node-side check confirmed three Up nodes, aggregate health Ok, and a healthy DNS service when enabled."
  value       = anytrue([for status in azapi_resource_action.runtime_health.output.value : status.code == "ComponentStatus/StdOut/succeeded" && strcontains(status.message, "AVM_HEALTH_OK_${var.validation_revision}")])
}

output "dns_service_verified" {
  description = "Whether the node-side check confirmed that fabric:/System/DnsService has an Ok aggregate health state."
  value       = anytrue([for status in azapi_resource_action.runtime_health.output.value : status.code == "ComponentStatus/StdOut/succeeded" && strcontains(status.message, "AVM_DNS_OK_${var.validation_revision}")])
}
