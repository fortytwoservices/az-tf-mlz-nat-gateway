variable "ignore_body_changes" {
  type = object({
    network_nat_gateways           = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])

    network_public_ip_addresses = optional(object({
      network_public_ip_addresses    = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
    }), {})
    network_public_ip_prefixes = optional(object({
      network_public_ip_prefixes     = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.idleTimeoutInMinutes`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `network_nat_gateways` - Ignored body paths for the NAT gateway.
- `authorization_locks` - Ignored body paths for the NAT gateway's lock.
- `authorization_role_assignments` - Ignored body paths for the NAT gateway's role assignments.
- `insights_diagnostic_settings` - Ignored body paths for the NAT gateway's diagnostic settings.
- `network_public_ip_addresses` - Slot for the `az-tf-mlz-public-ip` calls (its `network_public_ip_addresses` and interface keys).
- `network_public_ip_prefixes` - Slot for the `az-tf-mlz-public-ip` `modules/public_ip_prefix` calls (its `network_public_ip_prefixes` and interface keys).
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_nat_gateways           = optional(string, "Microsoft.Network/natGateways@2025-07-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")

    network_public_ip_addresses = optional(object({
      network_public_ip_addresses    = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
    }), {})
    network_public_ip_prefixes = optional(object({
      network_public_ip_prefixes     = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and the modules it calls. Each key defaults to a tested value; supply only the keys you want to override.

- `network_nat_gateways` - The NAT gateway.
- `authorization_locks` - The lock on the NAT gateway.
- `authorization_role_assignments` - Role assignments on the NAT gateway.
- `insights_diagnostic_settings` - Diagnostic settings on the NAT gateway.
- `network_public_ip_addresses` - Slot for the `az-tf-mlz-public-ip` calls. Defaults live in that module.
- `network_public_ip_prefixes` - Slot for the `az-tf-mlz-public-ip` `modules/public_ip_prefix` calls. Defaults live in that module.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module and the modules it calls. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module and the modules it calls. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
