---
description: Standalone common-name-secured regular Service Fabric cluster.
---

# Common-name certificate example

This example deploys a three-node Bronze Windows Service Fabric cluster and its
resource group, VM scale set, networking, Standard load balancer, and Key Vault.
It reuses the repository's operational test configuration, which invokes the
root cluster module and uses AzAPI for every Azure resource.

Common-name server authentication, administrator client authorization, DNS,
EventStore, EncryptAndSign protection, reverse-proxy authentication, and a custom
upgrade policy are enabled. A node-side check requires three Up nodes, Ok cluster
health, and a healthy DNS service before deployment succeeds.

## Prerequisites

Authenticate to an approved Azure subscription with resource-group, Key Vault
deployment, network, VM scale-set, and VM run-command permissions. Allow quota
for three `Standard_D2s_v5` instances in `westus3`, or set
`AVM_INTEGRATION_LOCATION` and `AVM_INTEGRATION_VM_SKU` before running the hook.

Locally, set `AVM_INTEGRATION_MANAGEMENT_CIDR` to your approved runner IPv4 CIDR.
The managed GitHub Actions `e2e-test` job discovers its runner IPv4 automatically
and allows only that `/32`. Discovery failure stops the deployment.

> [!WARNING]
> This example creates billable Azure resources. The generated self-signed
> certificate and Bronze topology are for isolated testing, not production.

## Run the example

From the repository root, use PowerShell 7.4 or later and Avm.Authoring:

```powershell
$env:AVM_INTEGRATION_MANAGEMENT_CIDR = '<approved-runner-ip>/32'
avm test e2e --example default
```

The pre-hook generates unique names, a real 45-day certificate, and a random VM
password in the owner-restricted, git-ignored `.generated` directory. The hook
supplies them through `avm.generated.auto.tfvars.json`, also owner-restricted and
git-ignored. Private values flow through ephemeral inputs into AzAPI write-only
bodies. No external resource IDs or certificate inputs need to be supplied.

The E2E runner applies the example, requires a no-change idempotency plan, then
destroys all managed resources. The post-hook removes generated credentials
after cleanup. Keep these files until destruction finishes; if resources remain
in Terraform state, the post-hook fails and retains them for a destroy retry.

For manual deployment, run these commands from this example directory after
setting the same environment variables:

```powershell
.\pre.ps1
terraform init
terraform plan
terraform apply
terraform destroy
.\post.ps1
```

Do not delete generated credentials or settings between apply and destroy. Remove any
settings files for the former existing-infrastructure example before running
this standalone configuration.

## CI policy planning

Policy planning uses the same infrastructure configuration without deploying
resources. In the managed `pr-check` job's isolated staging directory, the hook
uses the documentation-only CIDR `192.0.2.1/32` when none is configured. This
policy-only CIDR is not supplied to the E2E deployment job.

Example-local APRL exceptions cover Uniform VMSS and disabled automatic repairs
(Service Fabric requirements), plus the intentional regional Bronze topology
and bounded load-balancer egress of this non-production test. The public IP still
uses Standard SKU. These exceptions do not disable E2E or AVMSEC checks.
