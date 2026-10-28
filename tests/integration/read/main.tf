# Reads a NAT gateway straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "nat_gateway_id" {
  type = string
}

data "azapi_resource" "nat_gateway" {
  type                   = "Microsoft.Network/natGateways@2025-07-01"
  resource_id            = var.nat_gateway_id
  response_export_values = ["sku.name", "zones", "properties"]
}

locals {
  properties = data.azapi_resource.nat_gateway.output.properties
}

output "idle_timeout_in_minutes" {
  value = local.properties.idleTimeoutInMinutes
}

output "nat64" {
  value = try(local.properties.nat64, null)
}

output "public_ip_ids" {
  value = { for key in ["publicIpAddresses", "publicIpAddressesV6", "publicIpPrefixes", "publicIpPrefixesV6"] : key => sort([for item in try(local.properties[key], []) : lower(item.id)]) }
}

output "sku_name" {
  value = data.azapi_resource.nat_gateway.output.sku.name
}

output "zones" {
  value = try(data.azapi_resource.nat_gateway.output.zones, null)
}
