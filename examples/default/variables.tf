variable "admin_client_certificate_common_name" {
  type        = string
  description = "Common name of an existing client certificate authorized to administer the cluster. Keep its private key with the administrator, not in Terraform."
  nullable    = false
}

variable "admin_client_certificate_issuer_thumbprint" {
  type        = string
  description = "Public SHA-1 thumbprint of the certificate that issued the administrator's client certificate."
  nullable    = false
}

variable "certificate_common_name" {
  type        = string
  description = "Common name of the existing server certificate installed with its private key in LocalMachine/My on every node. Its DNS names must cover the management endpoint."
  nullable    = false
}

variable "certificate_issuer_thumbprint" {
  type        = string
  description = "Public SHA-1 thumbprint of the server certificate's issuer. For an isolated self-signed test certificate, this is its own thumbprint."
  nullable    = false
}

variable "management_endpoint" {
  type        = string
  description = "Existing HTTPS management endpoint, including port 19080, served by the separately managed load balancer and cluster nodes."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "Fully-qualified ARM resource ID of the existing resource group in which to create the cluster."
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

variable "location" {
  type        = string
  default     = "westus3"
  description = "Azure region of the existing cluster infrastructure."
  nullable    = false
}

variable "name" {
  type        = string
  default     = "sf-common-name-example"
  description = "Name of the new regular Service Fabric cluster."
  nullable    = false
}

variable "primary_node_type_name" {
  type        = string
  default     = "primary"
  description = "Primary node type name matching nodeTypeRef in the existing three-instance Windows VM scale set's Service Fabric extension."
  nullable    = false
}
