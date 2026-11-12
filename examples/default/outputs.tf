output "cluster_endpoint" {
  description = "Resource-provider endpoint to configure on the separately managed Service Fabric VM extension."
  value       = module.cluster.cluster_endpoint
}

output "cluster_id" {
  description = "Azure-generated identifier of the new cluster."
  value       = module.cluster.cluster_id
}

output "management_endpoint" {
  description = "HTTPS management endpoint supplied by the existing cluster infrastructure."
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
