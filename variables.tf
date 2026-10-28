variable "location" {
  type        = string
  description = "Azure region of the NAT gateway and the public IP addresses and prefixes it creates, for example `swedencentral`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the NAT gateway. A replacement (a change of `sku_name` or `zones`) needs a new name: the new gateway is created before the old one is deleted, so that subnets in the same configuration move to it first."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, periods, hyphens and underscores, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the NAT gateway is created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "idle_timeout_in_minutes" {
  type        = number
  default     = 4
  description = "(Optional) TCP idle timeout in minutes, 4 to 120. Defaults to `4`, Azure's default; a longer timeout holds SNAT ports longer."
  nullable    = false

  validation {
    condition     = var.idle_timeout_in_minutes >= 4 && var.idle_timeout_in_minutes <= 120 && floor(var.idle_timeout_in_minutes) == var.idle_timeout_in_minutes
    error_message = "`idle_timeout_in_minutes` must be a whole number from 4 to 120."
  }
}

variable "nat64_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Translate outbound IPv6 traffic to `64:ff9b::/96` into IPv4 (NAT64). StandardV2 only, and needs an IPv4 public IP address or prefix; the DNS64 that synthesises the AAAA records is the caller's. Defaults to `false`."
  nullable    = false

  validation {
    condition     = !var.nat64_enabled || var.sku_name == "StandardV2"
    error_message = "NAT64 needs `sku_name = \"StandardV2\"`."
  }
  validation {
    condition = !var.nat64_enabled || anytrue([
      anytrue([for public_ip in values(var.public_ips) : public_ip.ip_version == "IPv4"]),
      anytrue([for prefix in values(var.public_ip_prefixes) : prefix.ip_version == "IPv4"]),
      length(var.public_ip_resource_ids.ipv4) > 0,
      length(var.public_ip_prefix_resource_ids.ipv4) > 0,
    ])
    error_message = "NAT64 needs an IPv4 public IP address or prefix (Microsoft Learn)."
  }
}

variable "public_ip_prefix_resource_ids" {
  type = object({
    ipv4 = optional(list(string), [])
    ipv6 = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Existing public IP prefixes to attach, by IP version. They must have the NAT gateway's SKU and, for a zonal Standard gateway, its zone or all three (an address or prefix without zones is rejected).

- `ipv4` - (Optional) IPv4 prefix IDs.
- `ipv6` - (Optional) IPv6 prefix IDs. StandardV2 only.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in concat(var.public_ip_prefix_resource_ids.ipv4, var.public_ip_prefix_resource_ids.ipv6) :
      can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPPrefixes", id))
    ])
    error_message = "Each `public_ip_prefix_resource_ids` entry must be a public IP prefix resource ID."
  }
  validation {
    condition     = length(var.public_ip_prefix_resource_ids.ipv6) == 0 || var.sku_name == "StandardV2"
    error_message = "IPv6 prefixes need `sku_name = \"StandardV2\"`."
  }
}

variable "public_ip_prefixes" {
  type = map(object({
    name          = string
    prefix_length = number
    ip_version    = optional(string, "IPv4")
  }))
  default     = {}
  description = <<DESCRIPTION
(Optional) Public IP prefixes the module creates through `az-tf-mlz-public-ip` (`modules/public_ip_prefix`) and attaches, keyed by any stable name. Each gets the NAT gateway's SKU and zones.

- `name` - Name of the prefix.
- `prefix_length` - `28` to `31` for IPv4 (16 to 2 addresses), `124` to `127` for IPv6.
- `ip_version` - (Optional) `IPv4` (default) or `IPv6`, which needs StandardV2.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for prefix in values(var.public_ip_prefixes) : contains(["IPv4", "IPv6"], prefix.ip_version)])
    error_message = "Each `public_ip_prefixes[*].ip_version` must be `IPv4` or `IPv6`."
  }
  validation {
    condition = alltrue([
      for prefix in values(var.public_ip_prefixes) :
      prefix.ip_version == "IPv4" ? prefix.prefix_length >= 28 && prefix.prefix_length <= 31 : prefix.prefix_length >= 124 && prefix.prefix_length <= 127
    ])
    error_message = "A NAT gateway takes IPv4 prefixes of /28 to /31 and IPv6 prefixes of /124 to /127."
  }
  validation {
    condition     = alltrue([for prefix in values(var.public_ip_prefixes) : prefix.ip_version == "IPv4"]) || var.sku_name == "StandardV2"
    error_message = "IPv6 prefixes need `sku_name = \"StandardV2\"`."
  }
}

variable "public_ip_resource_ids" {
  type = object({
    ipv4 = optional(list(string), [])
    ipv6 = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Existing public IP addresses to attach, by IP version. They must have the NAT gateway's SKU and, for a zonal Standard gateway, its zone or all three (an address or prefix without zones is rejected).

- `ipv4` - (Optional) IPv4 address IDs.
- `ipv6` - (Optional) IPv6 address IDs. StandardV2 only.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in concat(var.public_ip_resource_ids.ipv4, var.public_ip_resource_ids.ipv6) :
      can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPAddresses", id))
    ])
    error_message = "Each `public_ip_resource_ids` entry must be a public IP address resource ID."
  }
  validation {
    condition     = length(var.public_ip_resource_ids.ipv6) == 0 || var.sku_name == "StandardV2"
    error_message = "IPv6 addresses need `sku_name = \"StandardV2\"`."
  }
}

variable "public_ips" {
  type = map(object({
    name       = string
    ip_version = optional(string, "IPv4")
  }))
  default     = {}
  description = <<DESCRIPTION
(Optional) Public IP addresses the module creates through `az-tf-mlz-public-ip` and attaches, keyed by any stable name. Each gets the NAT gateway's SKU and zones: a zonal Standard gateway rejects an address outside its zone.

- `name` - Name of the public IP address.
- `ip_version` - (Optional) `IPv4` (default) or `IPv6`, which needs StandardV2.

A NAT gateway uses at most 16 IPv4 addresses, counting those in prefixes, and on StandardV2 also 16 IPv6 addresses.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for public_ip in values(var.public_ips) : contains(["IPv4", "IPv6"], public_ip.ip_version)])
    error_message = "Each `public_ips[*].ip_version` must be `IPv4` or `IPv6`."
  }
  validation {
    condition     = alltrue([for public_ip in values(var.public_ips) : public_ip.ip_version == "IPv4"]) || var.sku_name == "StandardV2"
    error_message = "IPv6 addresses need `sku_name = \"StandardV2\"`."
  }
  # Prefixes given by ID are not counted: their size is not known here, and Azure rejects the excess.
  validation {
    condition = alltrue([
      for version in ["IPv4", "IPv6"] :
      length([for public_ip in values(var.public_ips) : public_ip if public_ip.ip_version == version]) +
      length(version == "IPv4" ? var.public_ip_resource_ids.ipv4 : var.public_ip_resource_ids.ipv6) +
      sum(concat([0], [for prefix in values(var.public_ip_prefixes) : pow(2, (version == "IPv4" ? 32 : 128) - prefix.prefix_length) if prefix.ip_version == version])) <= 16
    ])
    error_message = "A NAT gateway uses at most 16 IPv4 and 16 IPv6 addresses, counting the addresses in prefixes."
  }
}

variable "sku_name" {
  type        = string
  default     = "StandardV2"
  description = "(Optional) `StandardV2` (default: zone-redundant, IPv6, NAT64, flow logs) or `Standard` (zonal or no zone, IPv4 only). Its public IP addresses and prefixes must have the same SKU. Azure cannot change the SKU, so changing it replaces the NAT gateway and the addresses and prefixes it creates, which then need new names (see `name`). StandardV2 is not offered in Canada East, India South Central, Sweden South and West India."
  nullable    = false

  validation {
    condition     = contains(["Standard", "StandardV2"], var.sku_name)
    error_message = "`sku_name` must be `Standard` or `StandardV2`."
  }
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "(Optional) The one availability zone of a zonal Standard NAT gateway, for example `[\"1\"]`. Null (the default) leaves a Standard gateway in no zone, where Azure places it; a StandardV2 gateway is always zone-redundant and takes no zones. Azure cannot move a gateway between zones, so changing this replaces it and the addresses and prefixes it creates, which then need new names (see `name`)."

  validation {
    condition     = var.zones == null ? true : length(var.zones) == 1 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "`zones` must be null or one zone: `[\"1\"]`, `[\"2\"]` or `[\"3\"]`."
  }
  validation {
    condition     = var.zones == null || var.sku_name == "Standard"
    error_message = "Only a Standard NAT gateway takes `zones`; StandardV2 is zone-redundant."
  }
}
