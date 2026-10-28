output "name" {
  description = "Name of the NAT gateway."
  value       = azapi_resource.this.name
}

output "public_ip_addresses" {
  description = "The public IP addresses the module created, by key of `public_ips`."
  value       = { for key, public_ip in module.public_ip : key => public_ip.ip_address }
}

output "public_ip_prefixes" {
  description = "The public IP prefixes the module created, in CIDR notation, by key of `public_ip_prefixes`."
  value       = { for key, prefix in module.public_ip_prefix : key => prefix.ip_prefix }
}

output "public_ip_prefix_resource_ids" {
  description = "Resource IDs of the public IP prefixes the module created, by key of `public_ip_prefixes`."
  value       = { for key, prefix in module.public_ip_prefix : key => prefix.resource_id }
}

output "public_ip_resource_ids" {
  description = "Resource IDs of the public IP addresses the module created, by key of `public_ips`."
  value       = { for key, public_ip in module.public_ip : key => public_ip.resource_id }
}

output "resource_id" {
  description = "Resource ID of the NAT gateway, for the `natGateway` of the subnets that use it."
  value       = azapi_resource.this.id
}
