# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-ng-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

module "nat_gateway" {
  source = "../../"

  name      = "ng-mlz-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  public_ips = {
    egress = { name = "pip-ng-mlz-${random_string.suffix.result}" }
  }
  public_ip_prefixes = {
    egress = { name = "ippre-ng-mlz-${random_string.suffix.result}", prefix_length = 31 }
  }
  tags = local.tags
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-ng-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

# The subnet attaches itself to the NAT gateway; the gateway has no list of subnets to write.
resource "azapi_resource" "workload_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "snet-workload"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = {
      addressPrefixes       = ["10.0.0.0/26"]
      defaultOutboundAccess = false
      natGateway            = { id = module.nat_gateway.resource_id }
    }
  }

  response_export_values = []
}
