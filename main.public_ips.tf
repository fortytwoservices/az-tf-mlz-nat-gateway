# The gateway's SKU and zones, because Azure attaches only addresses and prefixes of the same SKU, and to a
# zonal Standard gateway only those in its zone. They inherit the gateway's create_before_destroy (main.tf),
# so a removed one is destroyed after the gateway's update, and a replaced one needs a new name.
module "public_ip" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"
  for_each = var.public_ips

  name                = each.value.name
  parent_id           = var.parent_id
  location            = var.location
  sku_name            = var.sku_name
  zones               = var.zones
  ip_version          = each.value.ip_version
  tags                = var.tags
  resource_types      = var.resource_types.network_public_ip_addresses
  ignore_body_changes = var.ignore_body_changes.network_public_ip_addresses
  retry               = var.retry
  timeouts            = var.timeouts
}

module "public_ip_prefix" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git//modules/public_ip_prefix?ref=v0.1.2"
  for_each = var.public_ip_prefixes

  name                = each.value.name
  parent_id           = var.parent_id
  location            = var.location
  prefix_length       = each.value.prefix_length
  sku_name            = var.sku_name
  zones               = var.zones
  ip_version          = each.value.ip_version
  tags                = var.tags
  resource_types      = var.resource_types.network_public_ip_prefixes
  ignore_body_changes = var.ignore_body_changes.network_public_ip_prefixes
  retry               = var.retry
  timeouts            = var.timeouts
}
