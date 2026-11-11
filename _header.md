---
description: Azure Verified Module for a regular Azure Service Fabric cluster.
---

# Azure Service Fabric cluster

This module manages one `Microsoft.ServiceFabric/clusters` resource through AzAPI.
It does not deploy a Service Fabric managed cluster.

## Prerequisites

Supply an existing resource group ID through `parent_id`, a management endpoint,
and node type definitions matching your separately managed VM scale sets and
Service Fabric VM extensions. Networking, load balancers, certificates, and
diagnostics storage accounts must be provisioned separately.

Supply exactly one server certificate configuration: `certificate` for
thumbprint-based authentication or `certificate_common_names` for common-name
authentication. Certificates must be installed on the cluster nodes.

Node types are embedded properties of the regular cluster, not standalone ARM
child resources. This module configures them but does not create virtual machines.
Changing the primary node type name, management endpoint, or VM image replaces
the cluster; changing its instance count does not trigger replacement.

Reverse-proxy certificates are optional. Supply either `reverse_proxy_certificate`
or `reverse_proxy_certificate_common_names`, install the certificates on the
nodes, and configure the reverse-proxy port on the relevant node types.

The optional `upgrade_policy` configures restart behavior, upgrade and health-check
durations, and health and delta-health thresholds. Leave it null to omit
`upgradeDescription`; supplying an object applies the documented input defaults.
These durations use Service Fabric TimeSpan strings, not the Go duration strings
used by the separate AzAPI operation `timeouts` input.

## Scope

The implementation supports node types, server, client, and reverse-proxy certificates,
Microsoft Entra authentication, runtime upgrade mode and version, reliability,
custom fabric settings, add-on features, EventStore, zonal upgrade modes, and an
existing diagnostics storage account, and cluster upgrade policies.
Application resources and standard AVM extension-resource interfaces are not
included in this implementation.

Terraform 1.11.0 or later and AzAPI 2.12 or later are required.
API-version overrides are available through `resource_types`. An overridden API
version must support the properties you configure.

`ignore_body_changes` accepts body-relative dot paths. Changes take effect only
after apply, and ignored configuration is not sent to Azure until the path is
removed.
