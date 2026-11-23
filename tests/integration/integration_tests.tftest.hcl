variables {
  fixture_settings = jsondecode(file("tests/integration/.generated/public.json"))
  fixture_secrets  = jsondecode(file("tests/integration/.generated/private.json"))
}

run "create_thumbprint_cluster" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  assert {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.ServiceFabric/clusters", output.resource_id)) && output.cluster_id != "" && startswith(output.cluster_endpoint, "https://")
    error_message = "Azure must return a regular cluster resource ID, generated cluster ID, and resource-provider endpoint."
  }

  assert {
    condition     = output.runtime_health_verified && output.vm_provisioning_state == "Succeeded" && output.persisted_configuration.properties.clusterState == "Ready"
    error_message = "The scale set must provision and the real cluster must reach Ready with three healthy nodes."
  }

  assert {
    condition     = lower(output.persisted_configuration.properties.certificate.thumbprint) == lower(output.certificate_thumbprint) && output.persisted_configuration.properties.reliabilityLevel == "Bronze" && length(output.persisted_configuration.properties.nodeTypes) == 1 && output.persisted_configuration.properties.nodeTypes[0].vmInstanceCount == 3
    error_message = "Azure must persist the thumbprint, Bronze reliability, and the three-node primary type."
  }
}

run "update_optional_configuration" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  variables {
    configure_optional_features = true
    validation_revision         = "updated"
  }

  assert {
    condition     = output.cluster_id == run.create_thumbprint_cluster.cluster_id && output.resource_id == run.create_thumbprint_cluster.resource_id && output.runtime_health_verified
    error_message = "Updating optional settings must preserve the Azure-generated cluster ID and restore healthy runtime operation."
  }

  assert {
    condition     = lower(output.persisted_configuration.properties.reverseProxyCertificate.thumbprint) == lower(output.certificate_thumbprint) && output.persisted_configuration.properties.eventStoreServiceEnabled && output.dns_service_verified && output.persisted_configuration.tags.phase == "configured"
    error_message = "Azure must persist reverse-proxy thumbprints, EventStore, and updated tags, and the running DNS system service must be healthy."
  }

  assert {
    condition     = output.persisted_configuration.properties.upgradeDescription.healthCheckRetryTimeout == "00:30:00" && output.persisted_configuration.properties.upgradeDescription.upgradeTimeout == "06:00:00" && output.persisted_configuration.properties.upgradeDescription.healthPolicy.maxPercentUnhealthyNodes == 0 && output.persisted_configuration.properties.upgradeDescription.deltaHealthPolicy.maxPercentDeltaUnhealthyNodes == 0
    error_message = "Azure must persist the configured upgrade durations and cluster/delta health thresholds."
  }
}

run "reapply_and_verify_health" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  variables {
    configure_optional_features = true
    validation_revision         = "reapplied"
  }

  assert {
    condition     = output.cluster_id == run.create_thumbprint_cluster.cluster_id && output.runtime_health_verified && output.persisted_configuration.properties.clusterState == "Ready"
    error_message = "Reapplying the configuration must keep the original cluster and pass a fresh guest health check."
  }
}
