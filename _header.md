# az-tf-mlz-nat-gateway

A Fortytwo managed landing zone (MLZ) module for Azure NAT Gateway, in AzAPI: the NAT gateway
(`Microsoft.Network/natGateways`) and the public IP addresses and prefixes it sends traffic out from.

- **StandardV2 by default**: zone-redundant, IPv4 and IPv6, NAT64 (`nat64_enabled`) and flow logs
  (`NatGatewayFlowlogsV1`, through `diagnostic_settings`). **Standard** is zonal (`zones`, one zone) or in
  no zone, IPv4 only. Azure changes neither the SKU nor the zone of an existing gateway, so changing either
  replaces it (see the replacements below). StandardV2 is not offered in Canada East, India South
  Central, Sweden South and West India.
- **Public IP addresses and prefixes** are created through
  [`az-tf-mlz-public-ip`](https://github.com/fortytwoservices/az-tf-mlz-public-ip) (`public_ips`,
  `public_ip_prefixes`, keyed by stable names) with the gateway's SKU and zone, which Azure requires, or
  given by ID per IP version (`public_ip_resource_ids`, `public_ip_prefix_resource_ids`). Up to 16 IPv4
  addresses, counting those in prefixes, and on StandardV2 also 16 IPv6. Removing one detaches it before
  it is destroyed (Azure deletes no address in use), because the gateway is `create_before_destroy`.
- **Subnets attach themselves**: a subnet sets `natGateway.id` to `resource_id`, as in the example. Azure
  deletes a gateway only once no subnet uses it, so a replacement (a change of `name`, `sku_name`, `zones`
  or `location`) creates the new gateway first: subnets in the same configuration move to it, then the old
  one is deleted. Subnets elsewhere must move before the old gateway can go.
- **A replacement needs new public IP addresses and prefixes**: the old gateway holds its own until it is
  deleted. Give the created ones new names and the existing ones other IDs, so the outbound addresses
  change. A replacement for another reason than a rename also needs a new `name`.
- **A `ReadOnly` lock blocks changes to the gateway itself**, as in every MLZ module: remove it, or use
  `CanNotDelete`, before changing the gateway. The module does not lift it automatically, which would
  defeat the lock.
- **Removing a setting reaches Azure.** Every address and prefix list is sent, empty when unset, because
  azapi compares only the keys in the body.
- Lock, role assignments and diagnostic settings, as in Azure Verified Modules, through
  [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces).

```hcl
module "nat_gateway" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-nat-gateway.git?ref=vX.Y.Z"

  name      = "ng-hub-swc"
  parent_id = "/subscriptions/<subscription>/resourceGroups/<resource group>"
  location  = "swedencentral"
  public_ip_prefixes = {
    egress = { name = "ippre-ng-hub-swc", prefix_length = 30 }
  }
}
```

The example deploys a StandardV2 gateway with a public IP address and a prefix, and a subnet that uses it
(`default`).
