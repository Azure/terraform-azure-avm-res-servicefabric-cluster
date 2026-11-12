variables {
  fixture_settings = jsondecode(file("tests/integration/.generated/public.json"))
  fixture_secrets  = jsondecode(file("tests/integration/.generated/private.json"))
}

run "create_common_name_cluster" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  variables {
    certificate_mode            = "common_name"
    configure_optional_features = true
  }

  assert {
    condition     = output.runtime_health_verified && output.vm_provisioning_state == "Succeeded" && output.persisted_configuration.properties.clusterState == "Ready"
    error_message = "A common-name-secured cluster must provision and reach Ready with three healthy nodes."
  }

  assert {
    condition     = output.persisted_configuration.properties.certificateCommonNames.commonNames[0].certificateCommonName == output.certificate_common_name && lower(output.persisted_configuration.properties.certificateCommonNames.commonNames[0].certificateIssuerThumbprint) == lower(output.certificate_thumbprint)
    error_message = "Azure must persist common name ${output.certificate_common_name} and issuer ${output.certificate_thumbprint}; received ${output.persisted_configuration.properties.certificateCommonNames.commonNames[0].certificateCommonName} and ${output.persisted_configuration.properties.certificateCommonNames.commonNames[0].certificateIssuerThumbprint}."
  }

  assert {
    condition     = output.persisted_configuration.properties.reverseProxyCertificateCommonNames.commonNames[0].certificateCommonName == output.certificate_common_name && output.dns_service_verified
    error_message = "Azure must persist the dedicated reverse-proxy common-name certificate, and the running DNS system service must be healthy."
  }
}

run "reapply_common_name_cluster" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  variables {
    certificate_mode            = "common_name"
    configure_optional_features = true
    validation_revision         = "reapplied"
  }

  assert {
    condition     = output.cluster_id == run.create_common_name_cluster.cluster_id && output.runtime_health_verified
    error_message = "Reapplying common-name configuration must preserve the cluster ID and pass a fresh runtime health check."
  }
}
