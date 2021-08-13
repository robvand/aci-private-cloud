provider "aci" {
  username = var.aci_username
  password = var.aci_password
  url      = var.apic_url
  insecure = true
}

provider "random" {
}

#Tenant creation
resource "random_string" "tenant_1" {
  length  = 16
  special = false
  lower = true
}

resource "aci_tenant" "tenant_1" {
  description = "Used for Production workloads"
  name        = random_string.tenant_1.id
  annotation  = "Production"
  name_alias  = "Production"
}

#VRF creation
resource "random_string" "vrf_1" {
  length  = 16
  special = false
  lower = true
}

resource "aci_vrf" "vrf_1" {
  tenant_dn              = aci_tenant.tenant_1.id
  name                   = random_string.vrf_1.id
  annotation             = "prod_vrf"
  bd_enforced_enable     = "no"
  ip_data_plane_learning = "enabled"
  knw_mcast_act          = "permit"
  name_alias             = "Production_VRF"
}

#Bridge Domain creation
resource "aci_bridge_domain" "bd" {
  for_each = var.bridge_domains
  name = replace(each.value.subnet, "/", "_")
  #name_alias = "alias_bd"
  name_alias = each.value.name_alias
  ip_learning = each.value.ip_learning
  unicast_route = each.value.unicast_route
  tenant_dn = aci_tenant.tenant_1.id
  relation_fv_rs_ctx = aci_vrf.vrf_1.id
}

#Subnet under BD creation
resource "aci_subnet" "subnets" {
  for_each         = aci_bridge_domain.bd
  parent_dn        = aci_bridge_domain.bd[each.key].id
  description      = "subnet"
  ip               = var.bridge_domains[each.key].subnet
  annotation       = "tag_subnet"
  ctrl             = ["querier", "nd"]
  name_alias       = "alias_subnet"
  preferred        = "no"
  scope            = ["public", "shared"]
  virtual          = "yes"
}

#Subnet under EPG creation for VRF route leaking (will be moved under VRF in future code)
resource "aci_subnet" "epg_subnets" {
  for_each         = aci_application_epg.epg
  parent_dn        = aci_application_epg.epg[each.key].id
  description      = "subnet"
  ip               = var.bridge_domains[each.key].subnet
  annotation       = "tag_subnet"
  ctrl             = ["querier", "nd"]
  name_alias       = "alias_subnet"
  preferred        = "no"
  scope            = ["public", "shared"]
  virtual          = "yes"
}

#Application Profile creation
resource "random_string" "app_1" {
  length  = 16
  special = false
  lower = true
}

resource "aci_application_profile" "ap_1" {
  tenant_dn  = aci_tenant.tenant_1.id
  name       = random_string.app_1.id
  annotation = "Staging"
  name_alias = "Prod"
}

#EPG creation
resource "aci_application_epg" "epg" {
  for_each                = aci_bridge_domain.bd
  application_profile_dn  = aci_application_profile.ap_1.id
  name                    = aci_bridge_domain.bd[each.key].name
  description             = "description"
  annotation              = "tag_epg"
  exception_tag           = "0"
  flood_on_encap          = "disabled"
  fwd_ctrl                = "none"
  has_mcast_source        = "no"
  is_attr_based_epg       = "no"
  match_t                 = "AtleastOne"
  name_alias              = aci_bridge_domain.bd[each.key].name_alias
  pc_enf_pref             = "unenforced"
  pref_gr_memb            = "exclude"
  prio                    = "unspecified"
  shutdown                = "no"
  relation_fv_rs_bd       = aci_bridge_domain.bd[each.key].id
}

##adding subnet to VRF for leaking TBD (doing this under EPG with the provider instead)
/*resource "aci_rest" "ext_subnet_rest" {
  depends_on = [
    aci_vrf.vrf_1,
    aci_subnet.subnets,
    aci_bridge_domain.bd,
  ]
  for_each = aci_subnet.subnets
  path = "/api/node/mo/uni/tn-${aci_tenant.tenant_1.name}/ctx-${aci_vrf.vrf_1.name}.json"
  payload = <<EOF
{
  "leakInternalSubnet":{
    "attributes":{
      "dn":"uni/tn-${aci_tenant.tenant_1.name}/ctx-${aci_vrf.vrf_1.name}/leakroutes/leakintsubnet-[${aci_subnet.subnets[each.key].ip}]",
      "ip":"${aci_subnet.subnets[each.key].ip}",
      "scope":"public",
      "rn":"leakintsubnet-[${aci_subnet.subnets[each.key].ip}]",
      "status":"created"},
      "children":[{
        "leakTo":{
          "attributes":{
            "scope":"public",
            "descr":"descrip",
            "tenantName":"common",
            "ctxName":"default",
            "rn":"to-[common]-[default]",
            "status":"created"
          },
          "children":[]}}]}}
  }
  EOF
}*/

#VMM Domain read
data "aci_vmm_domain" "vmm_domain" {
  provider_profile_dn = var.provider_profile_dn
  name                = var.vmm_domain
}

#Publishing EPG to VMM Domain
resource "aci_epg_to_domain" "epg_to_domain" {
  for_each                = aci_application_epg.epg
  application_epg_dn      = each.value.id
  tdn                     = data.aci_vmm_domain.vmm_domain.id
  allow_micro_seg         = false
  #primary_encap = var.vmm_primary_encaps[0]
  #encap = var.vmm_encaps[0]
  res_imedcy              = "immediate"
  instr_imedcy            = "immediate"
  annotation = "Test"
}

#Routing to common L3out

#Common tenant read
data "aci_tenant" "common_tenant" {
  name = var.common_tenant
}

#Commong L3out read
data "aci_l3_outside" "common_l3_out" {
  tenant_dn = data.aci_tenant.common_tenant.id
  name = var.common_l3_out
}

resource "aci_external_network_instance_profile" "network_instance_profile" {
    for_each = aci_application_epg.epg
    l3_outside_dn  = data.aci_l3_outside.common_l3_out.id
    description    = "ExtEPG used by ${aci_tenant.tenant_1.name} aka ${aci_tenant.tenant_1.name_alias}"
    name           = aci_tenant.tenant_1.name
    annotation     = aci_tenant.tenant_1.annotation
    flood_on_encap = "disabled"
    name_alias     = aci_tenant.tenant_1.annotation
    pref_gr_memb   = "exclude"
    relation_fv_rs_cons_if = [aci_application_epg.epg[each.key].id]
}

resource "aci_l3_ext_subnet" "ext_epg_subnet" {
  for_each = aci_bridge_domain.bd
  external_network_instance_profile_dn  = aci_external_network_instance_profile.network_instance_profile[each.key].id
  description                           = "L3 External subnet"
  ip                                    = "0.0.0.0/0"
  aggregate                             = "shared-rtctrl"
  annotation                            = "tag_ext_subnet"
  name_alias                            = "alias_ext_subnet"
  scope                                 = ["import-security","shared-security","import-rtctrl","shared-rtctrl"]
}

#Contract for external routing creation
resource "aci_contract" "external_routing" {
  for_each = aci_application_epg.epg
  #can we add a 'for tag = public' or something?
  tenant_dn   = aci_tenant.tenant_1.id
  description = ""
  name        = "${aci_application_epg.epg[each.key].name}-to-common"
  scope       = "global"
  target_dscp = "unspecified"
}

#Subject creation
resource "aci_contract_subject" "external_routing" {
  for_each = aci_contract.external_routing
    contract_dn   = aci_contract.external_routing[each.key].id
    description   = "external routing"
    name          = "subject"
    cons_match_t  = "AtleastOne"
    name_alias    = ""
    prov_match_t  = "AtleastOne"
    rev_flt_ports = "yes"
  relation_vz_rs_subj_filt_att = [aci_filter.external_routing_filter.id]
}

#Filter creation
resource "aci_filter" "external_routing_filter" {
    tenant_dn   = aci_tenant.tenant_1.id
    description = "any"
    name        = "any"
    annotation  = "any"
    name_alias  = "any"
}

#Filter entry creation
resource "aci_filter_entry" "external_routing_filter_entry" {
    filter_dn     = aci_filter.external_routing_filter.id
    description   = "any"
    name          = "any"
    annotation    = "any"
    apply_to_frag = "no"
    arp_opc       = "unspecified"
    d_from_port   = "unspecified"
    d_to_port     = "unspecified"
    ether_t       = "ipv4"
    icmpv4_t      = "unspecified"
    icmpv6_t      = "unspecified"
    name_alias    = "any"
    prot          = "unspecified"
    s_from_port   = "0"
    s_to_port     = "0"
    stateful      = "no"
}

#Exporting the external routing contracts to common (contract export in TF?)
resource "aci_rest" "tenant_rest" {
  depends_on = [
    aci_contract.external_routing,
    aci_external_network_instance_profile.network_instance_profile,
  ]
  for_each = aci_application_epg.epg
  path = "/api/node/mo/uni/tn-${data.aci_tenant.common_tenant.name}.json"
  payload = <<EOF
{
  "vzCPIf": {
    "attributes":{
      "dn":"uni/tn-${data.aci_tenant.common_tenant.name}/cif-${aci_application_epg.epg[each.key].name}",
      "name":"${aci_application_epg.epg[each.key].name}",
      "descr":"automated external routing",
      "rn":"cif-${aci_application_epg.epg[each.key].name}"},
      "children":[{
        "vzRsIf":{
          "attributes":{
            "tDn":"uni/tn-${aci_tenant.tenant_1.name}/brc-${aci_contract.external_routing[each.key].name}"},
      "children":[]}}]}}
}
EOF
}

#Providing the external routing contracts to each EPG
resource "aci_epg_to_contract" "aci_epgs_to_common" {
  for_each            = aci_application_epg.epg
  application_epg_dn  = aci_application_epg.epg[each.key].id
  contract_dn         = aci_contract.external_routing[each.key].id
  contract_type       = "provider"
}






