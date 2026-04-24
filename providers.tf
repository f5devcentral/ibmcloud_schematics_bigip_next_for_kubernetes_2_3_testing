# Default IBM provider — used for cluster data source lookups (cluster region)
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibmcloud_cluster_region
}

# VPC-region IBM provider — used for all jumphost and VPC resources.
# When using the cluster VPC (no client VPC created or specified), set
# client_vpc_region equal to ibmcloud_cluster_region.
provider "ibm" {
  alias            = "vpc_region"
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.testing_client_vpc_region
}
