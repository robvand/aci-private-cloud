variable "aci_username" {}
variable "aci_password" {}
variable "apic_url" {}

#List of networks to be added to ACI
variable "bridge_domains" {
  type = map(any)
  default = {
    bd-1 = {
      description   = "Application Core bridge"
      arp_flood     = "no"
      ip_learning   = "yes"
      unicast_route = "yes"
      subnet        = "1.1.20.1/24"
      name_alias    = "core_services"
      subnet_scope = [
      "private"]
    },
    bd-2 = {
      description   = "Web/Apache Front End bridge"
      arp_flood     = "yes"
      ip_learning   = "yes"
      unicast_route = "yes"
      subnet        = "1.1.30.1/24"
      name_alias    = "frontend_services"
      subnet_scope = [
      "private"]
    },
    bd-3 = {
      description   = "Backend services"
      arp_flood     = "yes"
      ip_learning   = "yes"
      unicast_route = "yes"
      subnet        = "1.1.40.1/24"
      name_alias    = "additional_services"
      subnet_scope = [
      "private"]
    },
  }
}
#Name of the VMM domain that the EPGs should be published to
variable "vmm_domain" {
  default = "HX-ACI"
}
variable "provider_profile_dn" {
  default = "/uni/vmmp-VMware"
}
#Optional configuration when using [allow microsegmentation] and you wish to use select VLANs
/*variable "vmm_primary_encaps" {
  type    = list(string)
  default = ["vlan-3303", "vlan-3305"]
}
variable "vmm_encaps" {
  type    = list(string)
  default = ["vlan-3304", "vlan-3306"]
}*/

#Tenant name that contains the shared L3out
variable "common_tenant" {
  default = "common"
}
#Shared L3out name
variable "common_l3_out" {
  default = "l3out_to_core_ospf"
}
