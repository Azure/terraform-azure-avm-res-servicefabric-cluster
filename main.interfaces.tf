module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.0"

  enable_telemetry                 = var.enable_telemetry
  location                         = var.location
  lock                             = var.lock
  role_assignment_definition_scope = azapi_resource.this.id
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "role_assignments" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_role_assignments
  body                   = each.value.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

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

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = coalesce(module.avm_interfaces.lock_azapi.name, "lock-${lower(var.lock.kind)}")
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.avm_interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Destroy the lock before role assignments so a ReadOnly lock cannot block their deletion.
  depends_on = [azapi_resource.role_assignments]
}
