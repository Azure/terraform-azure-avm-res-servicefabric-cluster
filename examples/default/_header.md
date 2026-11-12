---
description: Common-name-secured regular Service Fabric cluster using existing infrastructure.
---

# Common-name certificate example

This example creates one regular `Microsoft.ServiceFabric/clusters` resource
using AzAPI. It configures common-name server authentication, a separate
administrator client certificate, DNS service, EncryptAndSign protection,
and a common-name reverse-proxy certificate.

## Existing infrastructure

Supply an existing resource group and the following separately managed resources:

* A three-instance Windows VM scale set with Bronze durability and a primary
  Service Fabric node type matching `primary_node_type_name`.
* Networking, DNS, a load balancer, and restricted access to ports 19000, 19080,
  and 19081. The example uses application ports 20000-30000 and ephemeral ports
  49152-65534; these must match the node and network configuration.
* A server certificate installed with its private key in `LocalMachine/My` on
  every node. Its DNS names must cover the HTTPS management endpoint.
* An administrator client certificate and its private key, held by the client.
  Supply its common name and issuer's public thumbprint to authorize it.

The server certificate is also used for the reverse proxy. Its reverse-proxy
declaration omits issuer thumbprints because Azure currently rejects them.
Issuer thumbprints are public certificate fingerprints, not private keys.

Configure the separately managed VM scale set's Service Fabric extension with
the returned `cluster_endpoint`, the matching node type, and certificate settings.
Creating the ARM cluster resource alone does not provision nodes or prove that
the cluster is operational. This is a usage example with existing dependencies,
not a self-contained unattended E2E deployment.

## Run the example

From this directory, copy the sample settings:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Replace every placeholder in `terraform.tfvars` with your existing infrastructure
and certificate details. Do not put private keys, PFX contents, or passwords in
this file. Authenticate to the intended subscription, then review and apply:

```powershell
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Only the cluster resource is managed by this example. Destroying it leaves the
existing resource group, nodes, network, and certificates untouched.
