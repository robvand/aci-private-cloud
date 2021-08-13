# ACI as a private cloud using Terraform
This sample code helps you consume ACI in a way that you might typically want to consume a public cloud. This plan will fully automate the onboarding of a new tenant / environment on a Cisco ACI infrastructure.
The only thing a user has to add is a list of subnets in the variables.tf file (this could also be integrated with an IPAM). 
These subnets are made available to a VMware cluster so that an admin only has to go ahead and move the vNICs of their workloads to the correct Port Group. 
Their workloads will have external connectivity via a shared L3out. An additional benefit is that this plan will use random identifiers for each object and leverage the alias and description fields to include naming.

The plan included in this repository includes the following:

Cisco ACI:
1. Create a new Tenant with a random ID
2. Create a new VRF with a random ID
3. Create n new BDs based on number of entries in variables.tf
4. Create n new subnets under the new BDs
5. Create a new Application Profile with a random ID
6. Create n number of EPGs based on number of created BDs (1:1 mapping)
7. Publish the new EPGs to an existing VMM Domain (VMware)
8. Create a new ExtEPG under the common L3out
9. Create n contracts for each EPG and associate them with each EPG and the new ExtEPG (including export)

For each step the objects are created using random identifiers and the alias field is used where possible to simplify management and operations.

## Getting Started

Enter your APIC credentials and URL in terraform.tfvars file. Terraform.tfvars.example can be used as an example. 
Execute code lke below.
````
terraform init
terraform plan
terraform apply
````

### Prerequisites

1. Cisco ACI configured with a VMM domain and a shared L3out
