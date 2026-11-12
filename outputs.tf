output "cluster_endpoint" {
  description = "The resource-provider endpoint used by the Service Fabric VM extension. This is not the management endpoint."
  value       = azapi_resource.this.output.properties.clusterEndpoint
}

output "cluster_id" {
  description = "The Azure-generated unique identifier of the Service Fabric cluster."
  value       = azapi_resource.this.output.properties.clusterId
}

output "management_endpoint" {
  description = "The HTTP or HTTPS cluster management endpoint."
  value       = azapi_resource.this.body.properties.managementEndpoint
}

output "name" {
  description = "The name of the Service Fabric cluster."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "The resource ID of the Service Fabric cluster."
  value       = azapi_resource.this.id
}
