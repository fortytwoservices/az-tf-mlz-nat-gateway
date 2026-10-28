mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/natGateways/ng-test"
      output = {
        properties = {
          ipAddress = "203.0.113.10"
          ipPrefix  = "203.0.113.16/28"
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location  = "swedencentral"
  name      = "ng-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/natGateways@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The NAT gateway should use the default resource type, name, parent_id and location."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        idleTimeoutInMinutes = 4
        nat64                = "Disabled"
        publicIpAddresses    = []
        publicIpAddressesV6  = []
        publicIpPrefixes     = []
        publicIpPrefixesV6   = []
      }
      sku = { name = "StandardV2" }
    })
    error_message = "A StandardV2 gateway should send every list (empty when unset), NAT64 disabled, and no zones."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.replace_triggers_external_values) == jsonencode({ sku_name = "StandardV2", zones = null })
    error_message = "The SKU and the zones should be replacement triggers."
  }
  assert {
    condition     = azapi_resource.this.ignore_body_changes == null && azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "ignore_body_changes, retry and timeouts should be unset by default."
  }
  assert {
    condition     = length(module.public_ip) == 0 && length(module.public_ip_prefix) == 0 && module.interfaces.lock_resource_id == null
    error_message = "Nothing else should be created by default."
  }
}

run "created_and_existing_addresses_and_prefixes" {
  command = apply

  variables {
    public_ips = {
      b  = { name = "pip-ng-test-b" }
      a  = { name = "pip-ng-test-a" }
      v6 = { name = "pip-ng-test-v6", ip_version = "IPv6" }
    }
    public_ip_prefixes = {
      v4 = { name = "ippre-ng-test", prefix_length = 30 }
      v6 = { name = "ippre-ng-test-v6", prefix_length = 127, ip_version = "IPv6" }
    }
    public_ip_resource_ids = {
      ipv4 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"]
    }
    public_ip_prefix_resource_ids = {
      ipv6 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-existing-v6"]
    }
    nat64_enabled           = true
    idle_timeout_in_minutes = 10
  }

  assert {
    condition     = keys(module.public_ip) == ["a", "b", "v6"] && keys(module.public_ip_prefix) == ["v4", "v6"]
    error_message = "Each created address and prefix should be its own module call, keyed by its map key."
  }
  assert {
    condition = jsonencode(local.public_ip_ids) == jsonencode({
      ipv4 = [module.public_ip["a"].resource_id, module.public_ip["b"].resource_id, var.public_ip_resource_ids.ipv4[0]]
      ipv6 = [module.public_ip["v6"].resource_id]
    })
    error_message = "Addresses should be split by IP version, created ones first in key order, then the existing ones."
  }
  assert {
    condition = jsonencode(local.public_ip_prefix_ids) == jsonencode({
      ipv4 = [module.public_ip_prefix["v4"].resource_id]
      ipv6 = [module.public_ip_prefix["v6"].resource_id, var.public_ip_prefix_resource_ids.ipv6[0]]
    })
    error_message = "Prefixes should be split by IP version, created ones first, then the existing ones."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties) == jsonencode({
      idleTimeoutInMinutes = 10
      nat64                = "Enabled"
      publicIpAddresses    = [for id in local.public_ip_ids.ipv4 : { id = id }]
      publicIpAddressesV6  = [for id in local.public_ip_ids.ipv6 : { id = id }]
      publicIpPrefixes     = [for id in local.public_ip_prefix_ids.ipv4 : { id = id }]
      publicIpPrefixesV6   = [for id in local.public_ip_prefix_ids.ipv6 : { id = id }]
    })
    error_message = "The body should carry every address and prefix by version, the idle timeout and NAT64."
  }
  assert {
    condition     = jsonencode(output.public_ip_addresses) == jsonencode({ a = "203.0.113.10", b = "203.0.113.10", v6 = "203.0.113.10" }) && jsonencode(output.public_ip_prefixes) == jsonencode({ v4 = "203.0.113.16/28", v6 = "203.0.113.16/28" })
    error_message = "The created addresses and prefixes should be outputs, by key."
  }
}

run "zonal_standard" {
  command = apply

  variables {
    sku_name   = "Standard"
    zones      = ["2"]
    public_ips = { a = { name = "pip-ng-test-a" } }
  }

  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        idleTimeoutInMinutes = 4
        publicIpAddresses    = [{ id = module.public_ip["a"].resource_id }]
        publicIpAddressesV6  = []
        publicIpPrefixes     = []
        publicIpPrefixesV6   = []
      }
      sku   = { name = "Standard" }
      zones = ["2"]
    })
    error_message = "A zonal Standard gateway should send its zone and no NAT64."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.replace_triggers_external_values) == jsonencode({ sku_name = "Standard", zones = ["2"] })
    error_message = "The SKU and the zone should be replacement triggers."
  }
}

run "no_zone_standard" {
  command = plan

  variables {
    sku_name = "Standard"
  }

  assert {
    condition     = !contains(keys(azapi_resource.this.body), "zones") && azapi_resource.this.body.sku.name == "Standard"
    error_message = "A Standard gateway in no zone should send no zones."
  }
}

run "interfaces_and_overrides" {
  command = apply

  # Standard, because the overriding API version predates NAT64.
  variables {
    sku_name = "Standard"
    lock     = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = "55555555-5555-5555-5555-555555555555" }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        logs                  = [{ category = "NatGatewayFlowlogsV1" }]
      }
    }
    resource_types      = { network_nat_gateways = "Microsoft.Network/natGateways@2025-05-01" }
    ignore_body_changes = { network_nat_gateways = ["properties.idleTimeoutInMinutes"] }
    retry               = { error_message_regex = ["Conflict"] }
    timeouts            = { create = "30m" }
    tags                = { environment = "test" }
  }

  # The interface keys of resource_types and ignore_body_changes, retry and timeouts go to
  # az-tf-mlz-public-ip and az-tf-mlz-interfaces, whose tests check them; ignore_body_changes is write-only.
  assert {
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["reader"] && keys(module.interfaces.diagnostic_setting_resource_ids) == ["workspace"]
    error_message = "The lock, role assignments and diagnostic settings should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/natGateways@2025-05-01" && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "resource_types and tags should reach the NAT gateway."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.timeouts.create == "30m"
    error_message = "retry and timeouts should reach the NAT gateway."
  }
}

run "zones_on_standard_v2" {
  command = plan

  variables {
    zones = ["1"]
  }

  expect_failures = [var.zones]
}

run "two_zones" {
  command = plan

  variables {
    sku_name = "Standard"
    zones    = ["1", "2"]
  }

  expect_failures = [var.zones]
}

run "invalid_sku" {
  command = plan

  variables {
    sku_name = "Basic"
  }

  expect_failures = [var.sku_name]
}

run "invalid_idle_timeout" {
  command = plan

  variables {
    idle_timeout_in_minutes = 121
  }

  expect_failures = [var.idle_timeout_in_minutes]
}

run "invalid_name" {
  command = plan

  variables {
    name = "ng-test-"
  }

  expect_failures = [var.name]
}

run "nat64_on_standard" {
  command = plan

  variables {
    sku_name      = "Standard"
    nat64_enabled = true
    public_ips    = { a = { name = "pip-ng-test-a" } }
  }

  expect_failures = [var.nat64_enabled]
}

run "nat64_without_ipv4" {
  command = plan

  variables {
    nat64_enabled = true
    public_ips    = { v6 = { name = "pip-ng-test-v6", ip_version = "IPv6" } }
  }

  expect_failures = [var.nat64_enabled]
}

run "ipv6_address_on_standard" {
  command = plan

  variables {
    sku_name   = "Standard"
    public_ips = { v6 = { name = "pip-ng-test-v6", ip_version = "IPv6" } }
  }

  expect_failures = [var.public_ips]
}

run "ipv6_prefix_on_standard" {
  command = plan

  variables {
    sku_name           = "Standard"
    public_ip_prefixes = { v6 = { name = "ippre-ng-test-v6", prefix_length = 127, ip_version = "IPv6" } }
  }

  expect_failures = [var.public_ip_prefixes]
}

run "existing_ipv6_on_standard" {
  command = plan

  variables {
    sku_name                      = "Standard"
    public_ip_resource_ids        = { ipv6 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing-v6"] }
    public_ip_prefix_resource_ids = { ipv6 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-existing-v6"] }
  }

  expect_failures = [var.public_ip_resource_ids, var.public_ip_prefix_resource_ids]
}

run "more_than_16_ipv4_addresses" {
  command = plan

  variables {
    public_ips         = { a = { name = "pip-ng-test-a" } }
    public_ip_prefixes = { v4 = { name = "ippre-ng-test", prefix_length = 28 } }
  }

  expect_failures = [var.public_ips]
}

run "invalid_prefix_length" {
  command = plan

  variables {
    public_ip_prefixes = { v4 = { name = "ippre-ng-test", prefix_length = 27 } }
  }

  expect_failures = [var.public_ip_prefixes]
}

run "invalid_ip_version" {
  command = plan

  variables {
    public_ips = { a = { name = "pip-ng-test-a", ip_version = "IPv5" } }
  }

  expect_failures = [var.public_ips]
}

run "wrong_resource_types" {
  command = plan

  variables {
    public_ip_resource_ids        = { ipv4 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-existing"] }
    public_ip_prefix_resource_ids = { ipv4 = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"] }
  }

  expect_failures = [var.public_ip_resource_ids, var.public_ip_prefix_resource_ids]
}
