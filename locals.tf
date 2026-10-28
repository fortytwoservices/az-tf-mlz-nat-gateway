locals {
  # Created addresses first, in key order, then the existing ones in the order given, so the lists Azure
  # holds keep their order from plan to plan.
  public_ip_ids = {
    ipv4 = concat([for key, public_ip in module.public_ip : public_ip.resource_id if var.public_ips[key].ip_version == "IPv4"], var.public_ip_resource_ids.ipv4)
    ipv6 = concat([for key, public_ip in module.public_ip : public_ip.resource_id if var.public_ips[key].ip_version == "IPv6"], var.public_ip_resource_ids.ipv6)
  }
  public_ip_prefix_ids = {
    ipv4 = concat([for key, prefix in module.public_ip_prefix : prefix.resource_id if var.public_ip_prefixes[key].ip_version == "IPv4"], var.public_ip_prefix_resource_ids.ipv4)
    ipv6 = concat([for key, prefix in module.public_ip_prefix : prefix.resource_id if var.public_ip_prefixes[key].ip_version == "IPv6"], var.public_ip_prefix_resource_ids.ipv6)
  }
}
