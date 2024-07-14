project = "opsfleet"
environment = "dev"
region = "eu-west-1"
# Optionally can be used with personal IP address
cluster_endpoint_public_access = true
cluster_endpoint_public_access_cidrs = [""]
# Can be filled with outputs from VPC module
vpc_id = ""
subnet_ids = [""]
control_plane_subnet_ids = [""] 