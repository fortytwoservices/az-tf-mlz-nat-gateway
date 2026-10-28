output "public_ip_addresses" {
  description = "The NAT gateway's public IP addresses, the subnet's outbound addresses."
  value       = module.nat_gateway.public_ip_addresses
}

output "public_ip_prefixes" {
  description = "The NAT gateway's public IP prefixes."
  value       = module.nat_gateway.public_ip_prefixes
}

output "resource_id" {
  description = "Resource ID of the NAT gateway."
  value       = module.nat_gateway.resource_id
}
