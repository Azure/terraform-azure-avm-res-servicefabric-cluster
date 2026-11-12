output "cluster_endpoint" {
  description = "Resource-provider endpoint used by the deployed Service Fabric VM extension."
  value       = module.cluster.cluster_endpoint
}

output "cluster_id" {
  description = "Azure-generated identifier of the new cluster."
  value       = module.cluster.cluster_id
}

output "management_endpoint" {
  description = "Certificate-authenticated HTTPS management endpoint of the deployed cluster."
  value       = module.cluster.management_endpoint
}

output "name" {
  description = "Name of the new cluster."
  value       = module.cluster.name
}

output "resource_id" {
  description = "ARM resource ID of the new regular Service Fabric cluster."
  value       = module.cluster.resource_id
}

output "runtime_health_verified" {
  description = "Whether the node-side check confirmed three Up nodes and Ok aggregate cluster health."
  value       = module.cluster.runtime_health_verified
}
