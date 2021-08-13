# Terraform root plan

module "networking" {
  source       = "./networking"
  aci_username = var.aci_username
  aci_password = var.aci_password
  apic_url     = var.apic_url
}

# Work in progress - adding segmentation
/*module "security" {
  source = "./security"
  aci_username = var.aci_username
  aci_password = var.aci_password
  apic_url = var.apic_url
  aci_epgs = module.networking.EPGs.*
}*/
