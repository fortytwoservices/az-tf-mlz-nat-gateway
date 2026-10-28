# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Proves what mocks cannot: the default API version and body are accepted (StandardV2 with IPv4 and IPv6
# addresses, a prefix, NAT64 and flow logs; Standard zonal and in no zone) and read back as sent, removed
# addresses and prefixes leave the gateway before they are destroyed, the gateway is updated and replaced
# under its lock, and everything is destroyed. The empty second plan is the e2e test's (scripts/e2e.sh).

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create_standard_v2" {
  variables {
    name      = "ng-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    public_ips = {
      v4 = { name = "pip-mlz-ng-v4-${run.setup.suffix}" }
      v6 = { name = "pip-mlz-ng-v6-${run.setup.suffix}", ip_version = "IPv6" }
    }
    public_ip_prefixes = {
      v4 = { name = "ippre-mlz-ng-v4-${run.setup.suffix}", prefix_length = 31 }
    }
    nat64_enabled = true
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category = "NatGatewayFlowlogsV1" }]
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = can(cidrhost("${output.public_ip_addresses["v4"]}/32", 0)) && can(cidrhost("${output.public_ip_addresses["v6"]}/128", 0))
    error_message = "An IPv4 and an IPv6 address should be read back from Azure."
  }
  assert {
    condition     = endswith(output.public_ip_prefixes["v4"], "/31")
    error_message = "The /31 prefix should be read back from Azure."
  }
}

run "read_standard_v2" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    nat_gateway_id = run.create_standard_v2.resource_id
  }

  assert {
    condition     = output.sku_name == "StandardV2" && try(length(output.zones), 0) == 0 && output.nat64 == "Enabled" && output.idle_timeout_in_minutes == 4
    error_message = "Azure should hold a StandardV2 gateway without zones, with NAT64 and the default idle timeout."
  }
  assert {
    condition = jsonencode(output.public_ip_ids) == jsonencode({
      publicIpAddresses   = [lower(run.create_standard_v2.public_ip_resource_ids["v4"])]
      publicIpAddressesV6 = [lower(run.create_standard_v2.public_ip_resource_ids["v6"])]
      publicIpPrefixes    = [lower(run.create_standard_v2.public_ip_prefix_resource_ids["v4"])]
      publicIpPrefixesV6  = []
    })
    error_message = "Azure should hold each address and prefix in the list of its IP version."
  }
}

run "update_standard_v2_under_lock" {
  # The IPv6 address and the prefix are removed and destroyed, an existing address is added, NAT64 is
  # switched off and the idle timeout changed, all with the gateway locked.
  variables {
    name      = "ng-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    public_ips = {
      v4 = { name = "pip-mlz-ng-v4-${run.setup.suffix}" }
    }
    public_ip_resource_ids  = { ipv4 = [run.setup.public_ip_standard_v2_id] }
    idle_timeout_in_minutes = 10
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category = "NatGatewayFlowlogsV1" }]
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.resource_id == run.create_standard_v2.resource_id && keys(output.public_ip_resource_ids) == ["v4"] && length(output.public_ip_prefix_resource_ids) == 0
    error_message = "The gateway should be updated in place, and the removed address and prefix destroyed."
  }
}

run "read_updated_standard_v2" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    nat_gateway_id = run.update_standard_v2_under_lock.resource_id
  }

  assert {
    condition     = output.nat64 == "Disabled" && output.idle_timeout_in_minutes == 10
    error_message = "Azure should hold NAT64 off and the new idle timeout."
  }
  assert {
    condition = jsonencode(output.public_ip_ids) == jsonencode({
      publicIpAddresses   = sort([lower(run.update_standard_v2_under_lock.public_ip_resource_ids["v4"]), lower(run.setup.public_ip_standard_v2_id)])
      publicIpAddressesV6 = []
      publicIpPrefixes    = []
      publicIpPrefixesV6  = []
    })
    error_message = "Azure should hold the created and the existing IPv4 address and nothing else."
  }
}

run "replace_with_zonal_standard_under_lock" {
  # A SKU change replaces the gateway, under a new name, and the created address, which takes the gateway's
  # SKU and zone, also under a new name: the new ones are created first, the old ones deleted after (the
  # lock is moved). Flow logs are StandardV2's, so the diagnostic setting goes.
  variables {
    name      = "ng-mlz-it-z1-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_name  = "Standard"
    zones     = ["1"]
    public_ips = {
      v4 = { name = "pip-mlz-ng-z1-${run.setup.suffix}" }
    }
    public_ip_prefixes = {
      v4 = { name = "ippre-mlz-ng-z1-${run.setup.suffix}", prefix_length = 31 }
    }
    lock = { kind = "CanNotDelete" }
  }

  assert {
    condition     = output.resource_id != run.update_standard_v2_under_lock.resource_id && module.interfaces.lock_resource_id != null && length(output.public_ip_prefixes) == 1
    error_message = "The new gateway should be locked and have its prefix."
  }
}

run "read_zonal_standard" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    nat_gateway_id = run.replace_with_zonal_standard_under_lock.resource_id
  }

  assert {
    condition     = output.sku_name == "Standard" && jsonencode(output.zones) == jsonencode(["1"]) && output.nat64 == null
    error_message = "Azure should hold a Standard gateway in zone 1, without NAT64."
  }
  assert {
    condition     = length(output.public_ip_ids.publicIpAddresses) == 1 && length(output.public_ip_ids.publicIpPrefixes) == 1
    error_message = "Azure should hold the zonal address and prefix."
  }
}

run "replace_with_no_zone_standard" {
  # Removing the zone replaces the gateway, under a new name; an existing Standard address created without
  # zones is attached, and the created address and prefix are destroyed after the old gateway.
  variables {
    name                   = "ng-mlz-it-nz-${run.setup.suffix}"
    parent_id              = run.setup.resource_group_id
    location               = run.setup.location
    sku_name               = "Standard"
    public_ip_resource_ids = { ipv4 = [run.setup.public_ip_standard_id] }
  }

  assert {
    condition     = length(output.public_ip_resource_ids) == 0 && length(output.public_ip_prefix_resource_ids) == 0
    error_message = "The created address and prefix should be destroyed."
  }
}

run "read_no_zone_standard" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    nat_gateway_id = run.replace_with_no_zone_standard.resource_id
  }

  assert {
    condition     = output.sku_name == "Standard" && try(length(output.zones), 0) == 0 && jsonencode(output.public_ip_ids.publicIpAddresses) == jsonencode([lower(run.setup.public_ip_standard_id)])
    error_message = "Azure should hold a Standard gateway in no zone with the existing address."
  }
}
