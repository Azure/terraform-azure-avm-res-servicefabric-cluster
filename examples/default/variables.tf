variable "fixture_secrets" {
  type = object({
    admin_password     = string
    certificate_secret = string
  })
  description = "Ephemeral credentials supplied automatically by pre.ps1 through an owner-restricted, git-ignored generated settings file."
  nullable    = false
  sensitive   = true
  ephemeral   = true
}

variable "fixture_settings" {
  type = object({
    name_prefix              = string
    location                 = string
    vm_sku                   = string
    management_source_prefix = string
    certificate_common_name  = string
    certificate_thumbprint   = string
  })
  description = "Unique names, region, VM size, restricted management CIDR, and public certificate identifiers supplied automatically by pre.ps1."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}
