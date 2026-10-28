# A resource group, a Log Analytics workspace and two existing public IP addresses (StandardV2 and
# Standard) for one integration test run, and the identity running the test.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
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
  location  = "swedencentral"
}

resource "azapi_resource" "log_analytics_workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-ng-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }
}

module "public_ip_standard_v2" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"

  name      = "pip-mlz-ng-v2-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  sku_name  = "StandardV2"
}

module "public_ip_standard" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"

  name      = "pip-mlz-ng-std-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
}

output "location" {
  value = azapi_resource.resource_group.location
}

output "object_id" {
  value = data.azapi_client_config.current.object_id
}

output "public_ip_standard_id" {
  value = module.public_ip_standard.resource_id
}

output "public_ip_standard_v2_id" {
  value = module.public_ip_standard_v2.resource_id
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "suffix" {
  value = random_string.suffix.result
}

output "workspace_id" {
  value = azapi_resource.log_analytics_workspace.id
}
