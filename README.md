# BIG-IP Next for Kubernetes on IBM Cloud — Testing Jumphosts Workspace 2.3

## About This Workspace

This Schematics-ready Terraform workspace deploys testing jumphosts for validating BIG-IP Next for Kubernetes deployments in IBM Cloud. Two independent jumphost types can be enabled in any combination:

| Feature Flag | Jumphost Type | Placement |
|---|---|---|
| `create_tgw_jumphost` | Single jumphost in a client VPC | Client VPC in any region, optionally connected to the cluster via Transit Gateway |
| `create_cluster_jumphosts` | One jumphost per availability zone | Directly inside the cluster VPC, in every zone of `ibmcloud_cluster_region` |

Both types run the same Ubuntu 22.04 image and share the same SSH key name.

## Installed Software

Every jumphost is provisioned at boot with the following tools via `user_data`:

| Tool | Purpose |
|------|---------|
| IBM Cloud CLI + plugins | `container-service`, `openshift`, `vpc-infrastructure` |
| Docker CE | Container image pulls and local builds |
| Helm 3 | Helm chart inspection and manual installs |
| kubectl | Kubernetes API access |
| OpenShift CLI (`oc`) | OpenShift-specific cluster operations |
| `curl` | HTTP/HTTPS endpoint testing |
| `iperf3` | Network throughput measurement between jumphosts or to cluster nodes |
| `dig` (dnsutils) | DNS resolution testing and troubleshooting |
| `nc` (netcat) | TCP/UDP port reachability checks |
| `netstat` (net-tools) | Active connection and routing table inspection |

## TGW Jumphost

A single jumphost is created in a client VPC in `client_vpc_region`. The client VPC is connected to an existing IBM Cloud Transit Gateway (when `transit_gateway_name` is set), which bridges it to the cluster VPC across regions.

**VPC resolution when `create_tgw_jumphost = true`:**

| Mode | Configuration | Behaviour |
|------|---------------|-----------|
| Create new VPC | `create_client_vpc = true` | New VPC named `client_vpc_name` is created in `client_vpc_region` |
| Use existing VPC | `create_client_vpc = false` | Existing VPC named `client_vpc_name` is looked up in `client_vpc_region` |

The jumphost is placed in the first available zone of `client_vpc_region`. A dedicated security group permits inbound SSH from `0.0.0.0/0` and all outbound traffic. When `create_client_vpc = true`, the VPC default security group is also opened to all inbound traffic to simplify test access.

## Cluster Jumphosts

One jumphost is created per availability zone in the cluster VPC. The workspace looks up all zones in `ibmcloud_cluster_region` and creates the following per zone:

- A `/24` subnet
- A public gateway attached to the subnet
- A VSI instance
- A floating IP for external SSH access

All cluster jumphosts share a single security group (inbound SSH, all outbound) and the same SSH key.

The SSH key must exist in `ibmcloud_cluster_region` for cluster jumphosts and in `client_vpc_region` for the TGW jumphost. If both types are enabled with different regions, the key must be present in both regions under the same name.

## Deploying with IBM Schematics

### IBM Provider and IAM Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `ibmcloud_api_key` | API key used to authorize all deployment resources | REQUIRED | `0q7N3CzUn6oKxEsr7fLc1mxkukBeAEcsjNRQOg1kdDSY` (not a real key) |
| `ibmcloud_cluster_region` | IBM Cloud region where the referenced cluster resides | REQUIRED with default defined | `ca-tor` (default) |
| `ibmcloud_resource_group` | IBM Cloud resource group name (leave empty for account default) | Optional | `default` |

### Referenced Cluster

The workspace always looks up the referenced cluster to resolve its VPC ID for cluster jumphost placement.

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `cluster_name_or_id` | Name or ID of the existing IBM ROKs OpenShift cluster | REQUIRED | `my-openshift-cluster` |

### Feature Flags

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `create_tgw_jumphost` | Create a jumphost in a client VPC connected via Transit Gateway | REQUIRED with default defined | `false` (default) |
| `create_cluster_jumphosts` | Create one jumphost per availability zone in the cluster VPC | REQUIRED with default defined | `false` (default) |

### Shared Jumphost Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `ssh_key_name` | Name of the SSH key to inject into all jumphosts (must exist in each relevant region) | Optional | `my-ssh-key` |
| `jumphost_profile` | Instance profile for all jumphosts (leave empty to auto-select) | Optional | `bx2-4x16` |
| `min_vcpu_count` | Minimum vCPU count when auto-selecting the instance profile | Optional | `4` (default) |
| `min_memory_gb` | Minimum memory in GB when auto-selecting the instance profile | Optional | `8` (default) |

When `jumphost_profile` is empty the workspace queries available VPC instance profiles in the relevant region and picks the first profile meeting the `min_vcpu_count` and `min_memory_gb` thresholds. Falls back to `bx2-4x16` if no match is found.

### TGW Jumphost Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `create_client_vpc` | Create a new client VPC (`true`) or look up an existing one (`false`) | REQUIRED when `create_tgw_jumphost = true` | `false` (default) |
| `client_vpc_name` | Name of the client VPC to create or look up | REQUIRED when `create_tgw_jumphost = true` | `tf-testing-vpc` (default) |
| `client_vpc_region` | IBM Cloud region for the client VPC and TGW jumphost | REQUIRED when `create_tgw_jumphost = true` | `eu-gb` |
| `transit_gateway_name` | Name of an existing Transit Gateway to connect the client VPC to (leave empty to skip) | Optional | `tf-tgw` |
| `tgw_jumphost_name` | Name of the TGW jumphost instance (prefix for subnet, gateway, security group, and floating IP) | Optional | `tf-testing-jumphost-tgw` (default) |

### Cluster Jumphosts Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `cluster_jumphost_name_prefix` | Name prefix for cluster jumphosts — zone is appended as `<prefix>-<zone>` | Optional | `tf-testing-jumphost-cluster` (default) |

## Project Directory Structure

```
ibmcloud_schematics_bigip_next_for_kubernetes_2_3_testing/
├── main.tf                    # TGW jumphost and cluster jumphost resources
├── variables.tf               # All input variable declarations
├── outputs.tf                 # Cluster, TGW jumphost, and cluster jumphost outputs
├── providers.tf               # IBM provider configuration (default + vpc_region alias)
├── data.tf                    # Data sources for cluster, VPCs, images, profiles, SSH keys, TGW
└── terraform.tfvars.example   # Example variable values
```

## Configuration

### Required Variables (terraform.tfvars)

**TGW jumphost only — new client VPC in a different region, connected via Transit Gateway:**
```hcl
ibmcloud_api_key        = "YOUR_API_KEY"
ibmcloud_cluster_region = "ca-tor"

cluster_name_or_id = "my-openshift-cluster"

ssh_key_name = "my-ssh-key"   # must exist in eu-gb

create_tgw_jumphost      = true
create_cluster_jumphosts = false

create_client_vpc    = true
client_vpc_name      = "tf-testing-vpc"
client_vpc_region    = "eu-gb"
transit_gateway_name = "tf-tgw"
tgw_jumphost_name    = "tf-testing-jumphost-tgw"
```

**Cluster jumphosts only — one jumphost per zone in the cluster VPC:**
```hcl
ibmcloud_api_key        = "YOUR_API_KEY"
ibmcloud_cluster_region = "ca-tor"

cluster_name_or_id = "my-openshift-cluster"

ssh_key_name = "my-ssh-key"   # must exist in ca-tor

create_tgw_jumphost      = false
create_cluster_jumphosts = true

cluster_jumphost_name_prefix = "tf-testing-jumphost-cluster"
```

**Both types enabled:**
```hcl
ibmcloud_api_key        = "YOUR_API_KEY"
ibmcloud_cluster_region = "ca-tor"

cluster_name_or_id = "my-openshift-cluster"

# Key must exist in both ca-tor and eu-gb
ssh_key_name = "my-ssh-key"

create_tgw_jumphost      = true
create_cluster_jumphosts = true

# TGW jumphost — separate VPC in eu-gb
create_client_vpc    = true
client_vpc_name      = "tf-testing-vpc"
client_vpc_region    = "eu-gb"
transit_gateway_name = "tf-tgw"
tgw_jumphost_name    = "tf-testing-jumphost-tgw"

# Cluster jumphosts — one per zone in ca-tor cluster VPC
cluster_jumphost_name_prefix = "tf-testing-jumphost-cluster"
```

## Deployment

### Prerequisites
1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your API key and cluster name
2. Run `terraform init` to download provider plugins
3. Ensure the referenced cluster exists and is reachable with the provided API key
4. Ensure the SSH key exists in the required region(s)

### Deploy
```bash
terraform plan
terraform apply -auto-approve
```

### Cleanup
```bash
terraform destroy -auto-approve
```

## Outputs

```bash
terraform output                              # All outputs
terraform output tgw_jumphost_ssh_command     # TGW jumphost SSH command
terraform output cluster_jumphost_ssh_commands  # Map of zone -> SSH command
```

### TGW Jumphost Outputs

| Output | Description |
|--------|-------------|
| `tgw_jumphost_vpc_id` | ID of the VPC containing the TGW jumphost |
| `tgw_jumphost_vpc_name` | Name of the VPC containing the TGW jumphost |
| `tgw_jumphost_id` | Instance ID of the TGW jumphost |
| `tgw_jumphost_private_ip` | Private IP address of the TGW jumphost |
| `tgw_jumphost_public_ip` | Floating (public) IP address of the TGW jumphost |
| `tgw_jumphost_ssh_command` | Ready-to-use SSH command for the TGW jumphost |
| `tgw_jumphost_zone` | Availability zone where the TGW jumphost was placed |
| `tgw_jumphost_profile_used` | Instance profile selected for the TGW jumphost |
| `transit_gateway_connection_id` | ID of the Transit Gateway VPC connection |

### Cluster Jumphost Outputs (maps keyed by zone)

| Output | Description |
|--------|-------------|
| `cluster_jumphost_ids` | Map of zone to instance ID |
| `cluster_jumphost_private_ips` | Map of zone to private IP address |
| `cluster_jumphost_public_ips` | Map of zone to floating IP address |
| `cluster_jumphost_ssh_commands` | Map of zone to ready-to-use SSH command |

Example cluster jumphost output for a three-zone cluster:
```
cluster_jumphost_ssh_commands = {
  "ca-tor-1" = "ssh -i my-ssh-key ubuntu@169.55.12.10"
  "ca-tor-2" = "ssh -i my-ssh-key ubuntu@169.55.12.11"
  "ca-tor-3" = "ssh -i my-ssh-key ubuntu@169.55.12.12"
}
```

### Cluster Reference Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | ID of the referenced OpenShift cluster |
| `cluster_name` | Name of the referenced OpenShift cluster |

## Debugging and Troubleshooting

**Plan specific resources:**
```bash
terraform plan -target=ibm_is_instance.tgw_jumphost
terraform plan -target=ibm_is_instance.cluster_jumphost
terraform plan -target=ibm_tg_connection.tgw_vpc_connection
```

**List all managed resources:**
```bash
terraform state list
terraform state list 'ibm_is_instance.cluster_jumphost'
```

**Validate configuration:**
```bash
terraform validate
```

**Common issues:**

| Issue | Solution |
|-------|----------|
| `cluster_name_or_id` not found | Verify with `ibmcloud ks clusters --provider vpc-gen2` in `ibmcloud_cluster_region` |
| SSH key not found in cluster region | Verify with `ibmcloud is keys --region <ibmcloud_cluster_region>` |
| SSH key not found in client VPC region | Verify with `ibmcloud is keys --region <client_vpc_region>` |
| No eligible instance profile found | Lower `min_vcpu_count` or `min_memory_gb`, or set `jumphost_profile` explicitly |
| TGW jumphost unreachable via SSH | Confirm the floating IP is assigned (`terraform output tgw_jumphost_public_ip`) |
| Cluster jumphost unreachable via SSH | Confirm floating IPs are assigned (`terraform output cluster_jumphost_public_ips`) |
| Transit Gateway connection fails | Confirm the TGW exists and the API key has permission to create connections |
| `create_tgw_jumphost = true` but no VPC specified | Set `create_client_vpc = true` or provide `client_vpc_name` for an existing VPC |
