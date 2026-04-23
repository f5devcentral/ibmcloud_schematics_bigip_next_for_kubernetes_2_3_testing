# ============================================================
# Resource Group
# ============================================================

data "ibm_resource_groups" "all" {}

data "ibm_resource_group" "resource_group" {
  name = var.ibmcloud_resource_group != "" ? var.ibmcloud_resource_group : [
    for rg in data.ibm_resource_groups.all.resource_groups :
    rg.name if rg.is_default == true
  ][0]
}

# ============================================================
# Cluster (always required)
# ============================================================

data "ibm_container_vpc_cluster" "cluster" {
  name              = var.cluster_name_or_id
  resource_group_id = data.ibm_resource_group.resource_group.id
}

# ============================================================
# Cluster Jumphost Data Sources
# Provider: ibm (default — cluster region)
# ============================================================

# Cluster VPC — resolved from cluster metadata
data "ibm_is_vpc" "cluster_vpc" {
  count      = var.create_cluster_jumphosts ? 1 : 0
  identifier = data.ibm_container_vpc_cluster.cluster.vpc_id
}

# All availability zones in the cluster region
data "ibm_is_zones" "cluster_region_zones" {
  count  = var.create_cluster_jumphosts ? 1 : 0
  region = var.ibmcloud_cluster_region
}

# Ubuntu images in cluster region
data "ibm_is_images" "cluster_ubuntu_images" {
  count      = var.create_cluster_jumphosts ? 1 : 0
  visibility = "public"
  status     = "available"
}

# Instance profiles in cluster region (only when auto-selecting)
data "ibm_is_instance_profiles" "cluster_profiles" {
  count = (var.create_cluster_jumphosts && var.jumphost_profile == "") ? 1 : 0
}

# SSH key in cluster region
data "ibm_is_ssh_key" "cluster_ssh_key" {
  count = (var.create_cluster_jumphosts && var.ssh_key_name != "") ? 1 : 0
  name  = var.ssh_key_name
}

# ============================================================
# TGW Jumphost Data Sources
# Provider: ibm.vpc_region (client VPC region)
# ============================================================

# Existing client VPC — looked up when not creating a new one
data "ibm_is_vpc" "existing_client_vpc" {
  count    = (var.create_tgw_jumphost && !var.create_client_vpc) ? 1 : 0
  provider = ibm.vpc_region
  name     = var.client_vpc_name
}

# First availability zone in the client VPC region (for jumphost placement)
data "ibm_is_zones" "vpc_region_zones" {
  count    = var.create_tgw_jumphost ? 1 : 0
  provider = ibm.vpc_region
  region   = var.client_vpc_region
}

# Ubuntu images in client VPC region
data "ibm_is_images" "tgw_ubuntu_images" {
  count      = var.create_tgw_jumphost ? 1 : 0
  provider   = ibm.vpc_region
  visibility = "public"
  status     = "available"
}

# Instance profiles in client VPC region (only when auto-selecting)
data "ibm_is_instance_profiles" "tgw_profiles" {
  count    = (var.create_tgw_jumphost && var.jumphost_profile == "") ? 1 : 0
  provider = ibm.vpc_region
}

# SSH key in client VPC region
data "ibm_is_ssh_key" "tgw_ssh_key" {
  count    = (var.create_tgw_jumphost && var.ssh_key_name != "") ? 1 : 0
  provider = ibm.vpc_region
  name     = var.ssh_key_name
}

# Transit Gateway (global resource — uses default provider)
data "ibm_tg_gateway" "transit_gateway" {
  count = (var.create_tgw_jumphost && var.transit_gateway_name != "") ? 1 : 0
  name  = var.transit_gateway_name
}
