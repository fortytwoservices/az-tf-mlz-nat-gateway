module "interfaces" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-interfaces.git?ref=v0.1.1"

  resource_id = azapi_resource.this.id
  location    = var.location
  # Role definitions are looked up by name in the resource group, which exists before the NAT gateway, so
  # an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
  lock                             = var.lock
  role_assignments                 = var.role_assignments
  diagnostic_settings              = var.diagnostic_settings
  resource_types                   = var.resource_types # its interface keys are read
  ignore_body_changes              = var.ignore_body_changes
  retry                            = var.retry
  timeouts                         = var.timeouts
}
