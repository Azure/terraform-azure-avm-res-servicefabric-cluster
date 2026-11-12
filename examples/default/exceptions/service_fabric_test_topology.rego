package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# Service Fabric is supported on Uniform VMSS, not Flexible orchestration.
# https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes#feature-comparison
exception contains rules if {
    rules = ["virtual_machine_scaleset_orchestration_mode_flexible"]
}

# Automatic instance repairs are not supported for Service Fabric scale sets.
# https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-instance-repairs#requirements-for-using-automatic-instance-repairs
exception contains rules if {
    rules = ["virtual_machine_scaleset_enable_automatic_repair"]
}

# This short-lived three-node Bronze test intentionally does not deploy the
# larger Silver-durability topology needed for a zone-resilient cluster.
# https://learn.microsoft.com/azure/service-fabric/service-fabric-cross-availability-zones
exception contains rules if {
    rules = ["virtual_machine_scaleset_zonal_support"]
}

# The Standard public IP serves the same regional, non-zone-resilient test
# topology; production zone redundancy is outside this example's scope.
exception contains rules if {
    rules = ["use_standard_sku_and_zone_redundant_ip"]
}

# This is a fixed three-node, non-production test, not a production workload.
# Its explicit Standard LB outbound rule supplies bootstrap egress; a separate
# NAT gateway's production scalability is not required for this bounded test.
exception contains rules if {
    rules = ["use_nat_gateway_instead_of_outbound_rules_for_production_load_balancer"]
}
