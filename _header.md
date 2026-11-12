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

## Usage example

The [common-name certificate example](./examples/default/README.md) creates a
regular cluster using existing networking, three Windows nodes, and certificates.
It includes administrator client authorization and a reverse-proxy certificate.
It does not deploy or validate the supporting infrastructure.

## Integration tests

The real-Azure suite deploys two scenarios sequentially: thumbprint-based
certificates with a configuration update, and common-name certificates with
reverse-proxy and upgrade-policy settings. Each scenario creates a three-node
Bronze Windows cluster, a VM scale set, networking, a restricted Standard load
balancer, and a Key Vault. These are billable resources, not mocked tests.
There are five apply runs. Allow at least 90 minutes for the full suite, including
cluster startup, configuration upgrades, health checks, and teardown.
Use `avm test unit` for fast, Azure-free development checks.

The setup hook generates a 45-day self-signed certificate and a random VM
administrator password in an owner-restricted, git-ignored directory. The private
material is passed only through AzAPI write-only bodies. The self-signed
certificate is for isolated testing, not production.
Its lifetime stays above the default certificate-expiry health-warning threshold.
The server common-name declaration pins its issuer; reverse-proxy common-name
declarations omit issuer thumbprints because Azure currently rejects them.
The certificate secret is uploaded with an ARM PUT action and removed with its
vault, because the ARM secret endpoint does not support DELETE.

Authenticate to an approved Azure subscription with resource-group creation,
Key Vault deployment, network, VM scale-set, and VM run-command permissions.
Allow enough regional quota for three instances of the selected VM size.
From PowerShell 7.4 or later, run:

```powershell
.\tests\integration\Invoke-IntegrationTests.ps1 `
  -SubscriptionId '<approved-subscription-guid>' `
  -ManagementSourcePrefix '<approved-runner-ip>/32' `
  -Location 'westus3' `
  -VmSku 'Standard_D2s_v5'
```

The wrapper verifies the selected subscription and invokes `avm test integration`.
It removes generated local credentials on completion or failure. Guest-side
certificate-authenticated checks require all three nodes to be Up and aggregate
cluster health to be Ok within 20 minutes. When DNS is enabled, the checks also
require `fabric:/System/DnsService` to report Ok health. DNS enablement is checked
at runtime rather than through `addOnFeatures`, which Azure can omit from ARM
readback. Fresh ARM reads verify the other persisted configuration; reapply checks
preserve the Azure-generated cluster ID.
These reapply checks do not claim a zero-change Terraform plan.

Local PowerShell tests cover credential generation, private-file permissions,
target selection, and cleanup without calling Azure. After `avm pre-commit`
resolves the managed Pester tool, run them separately from `avm test unit`:

```powershell
Import-Module (avm tool which Pester --passthru).Path
Invoke-Pester -Path .\tests\unit\IntegrationSetup.Tests.ps1
```

Managed CI can call `avm test integration` directly after setting
`AVM_INTEGRATION_MANAGEMENT_CIDR` to an approved IPv4 CIDR.
`AVM_INTEGRATION_LOCATION` and `AVM_INTEGRATION_VM_SKU` are optional overrides.
When running without the wrapper, remove local credentials afterward with
`pwsh -File .\tests\integration\setup.ps1 -Cleanup`.

Terraform test tears down its Azure resources after each test file. If teardown
fails, inspect its reported resource IDs and remove the remaining test resources
before retrying. Deleted Key Vaults remain soft-deleted for seven days; unique
scenario names avoid collisions. Examples and telemetry are not exercised.
