resource "azapi_resource" "this" {
  location = var.location
  name     = var.name
  type     = "Microsoft.Resources/resourceGroups@2024-11-01"
  tags     = var.tags
}
