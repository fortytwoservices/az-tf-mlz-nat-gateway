resource "azapi_resource" "this" {
  type      = var.resource_types.network_nat_gateways
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = merge(
    {
      sku = { name = var.sku_name }
      # Every list is sent, empty when unset: azapi's ignore_no_op_changes compares only the keys in the
      # configuration, so a list left out would never be cleared in Azure.
      properties = merge(
        {
          idleTimeoutInMinutes = var.idle_timeout_in_minutes
          publicIpAddresses    = [for id in local.public_ip_ids.ipv4 : { id = id }]
          publicIpAddressesV6  = [for id in local.public_ip_ids.ipv6 : { id = id }]
          publicIpPrefixes     = [for id in local.public_ip_prefix_ids.ipv4 : { id = id }]
          publicIpPrefixesV6   = [for id in local.public_ip_prefix_ids.ipv6 : { id = id }]
        },
        # NAT64 exists on StandardV2 only; a Standard gateway reads it back as null.
        var.sku_name == "StandardV2" ? { nat64 = var.nat64_enabled ? "Enabled" : "Disabled" } : null,
      )
    },
    # Only a zonal Standard gateway has zones. StandardV2 is zone-redundant without them (Azure reads its
    # zones back as null).
    var.zones == null ? null : { zones = var.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_nat_gateways) > 0 ? var.ignore_body_changes.network_nat_gateways : null
  # Azure changes neither the SKU nor the zones of an existing gateway (Microsoft Learn). Inputs rather
  # than body paths, so that removing the zones also replaces it.
  replace_triggers_external_values = {
    sku_name = var.sku_name
    zones    = var.zones
  }
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Azure deletes neither an address or prefix the gateway uses nor a gateway a subnet uses. Terraform
  # passes create_before_destroy on to the addresses and prefixes this depends on, so a removed one is
  # detached by the gateway's update before it is destroyed (otherwise it is destroyed first, and fails).
  # A replacement creates the new gateway first, so it needs a new name, and the subnets in the same
  # configuration move to it before the old one is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
