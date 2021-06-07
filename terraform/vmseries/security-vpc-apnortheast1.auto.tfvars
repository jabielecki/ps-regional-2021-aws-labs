### Global ###

prefix_name_tag  = "ps-lab-"
fw_instance_type = "m5.xlarge"
fw_license_type  = "byol"
fw_version       = "10.0.4" # Can be empty.

global_tags = {
  managedBy   = "terraform"
  application = "Palo Alto Networks VM-Series GWLB"
  owner       = "PS Regional Training 2021"
}

### Security VPC ###

security_vpc = {
  vmseries-vpc = {
    name                 = "security"
    cidr_block           = "10.100.0.0/23"
    instance_tenancy     = "default"
    enable_dns_support   = true
    enable_dns_hostnames = true
    internet_gateway     = true
  }
}

# security_vpc_route_tables = {
# Not needed currently: by default each subnet is also creating exactly one route_table.
# }

security_vpc_subnets = {
  # Do not modify value of `set=`, it is an internal identifier referenced by main.tf.
  "10.100.0.0/28"  = { az = "ap-northeast-1a", set = "mgmt" }
  "10.100.1.0/28"  = { az = "ap-northeast-1c", set = "mgmt" }
  "10.100.0.16/28" = { az = "ap-northeast-1a", set = "data" }
  "10.100.1.16/28" = { az = "ap-northeast-1c", set = "data" }
  "10.100.0.32/28" = { az = "ap-northeast-1a", set = "gwlbe-eastwest" }
  "10.100.1.32/28" = { az = "ap-northeast-1c", set = "gwlbe-eastwest" }
  "10.100.0.48/28" = { az = "ap-northeast-1a", set = "gwlbe-outbound" }
  "10.100.1.48/28" = { az = "ap-northeast-1c", set = "gwlbe-outbound" }
  "10.100.0.64/28" = { az = "ap-northeast-1a", set = "tgw-attach" }
  "10.100.1.64/28" = { az = "ap-northeast-1c", set = "tgw-attach" }
  "10.100.0.80/28" = { az = "ap-northeast-1a", set = "natgw", local_tags = { Name = "my-us1-natgw-subnet" } }
  "10.100.1.80/28" = { az = "ap-northeast-1c", set = "natgw", local_tags = { Name = "my-us2-natgw-subnet" }, create_route_table = false, route_table = "my-us1-natgw-subnet" }
}

security_vpc_endpoints = {
}

security_vpc_security_groups = {
  vmseries-data = {
    name = "vmseries-data"
    rules = {
      all-outbound = {
        description = "Permit All traffic outbound"
        type        = "egress", from_port = "0", to_port = "0", protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
      geneve = {
        description = "Permit GENEVE"
        type        = "ingress", from_port = "6081", to_port = "6081", protocol = "udp"
        cidr_blocks = ["10.100.0.16/28", "10.100.1.16/28"]
      }
      health_probe = {
        description = "Permit Port 80 GWLB Health Probe"
        type        = "ingress", from_port = "80", to_port = "80", protocol = "tcp"
        cidr_blocks = ["10.100.0.16/28", "10.100.1.16/28"]
      }

    }
  }
  gwlbe = {
    name = "gwlbe"
    rules = {
      all-outbound = {
        description = "Permit All traffic outbound"
        type        = "egress", from_port = "0", to_port = "0", protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
      ssh2 = {
        description = "Permit traffic from any vpc"
        type        = "ingress", from_port = "0", to_port = "0", protocol = "-1"
        cidr_blocks = ["10.0.0.0/8"]
      }
    }
  }
  vmseries-mgmt = {
    name = "vmseries-mgmt"
    rules = {
      all-outbound = {
        description = "Permit All traffic outbound"
        type        = "egress", from_port = "0", to_port = "0", protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
      ssh-from-inet = {
        description = "Permit SSH"
        type        = "ingress", from_port = "22", to_port = "22", protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # TODO: update here
      }
      https-from-inet = {
        description = "Permit HTTPS"
        type        = "ingress", from_port = "443", to_port = "443", protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # TODO: update here
      }
      panorama-mgmt = {
        description = "Permit Panorama Management"
        type        = "ingress", from_port = "3978", to_port = "3978", protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
      https = {
        description = "Permit Panorama Logging"
        type        = "ingress", from_port = "28443", to_port = "28443", protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }
}

### VMSERIES ###

# firewalls = [
# Moved to student.auto.tfvars
# ]

interfaces = [
  # vmseries01
  {
    name                          = "vmseries01-data"
    source_dest_check             = false
    subnet_name                   = "data1"
    security_group                = "vmseries-data"
    private_ip_address_allocation = "dynamic"
  },
  {
    name                          = "vmseries01-mgmt"
    source_dest_check             = true
    subnet_name                   = "mgmt1"
    security_group                = "vmseries-mgmt"
    private_ip_address_allocation = "dynamic"
    eip                           = "vmseries01-mgmt"
  },
  # vmseries02
  {
    name                          = "vmseries02-data"
    source_dest_check             = false
    subnet_name                   = "data2"
    security_group                = "vmseries-data"
    private_ip_address_allocation = "dynamic"
  },
  {
    name                          = "vmseries02-mgmt"
    source_dest_check             = true
    subnet_name                   = "mgmt2"
    security_group                = "vmseries-mgmt"
    private_ip_address_allocation = "dynamic"
    eip                           = "vmseries02-mgmt"
  },
]

# addtional_interfaces = {}

### Security VPC ROUTES ###

summary_cidr_behind_natgw          = "0.0.0.0/0"
summary_cidr_behind_tgw            = "10.0.0.0/8"
summary_cidr_behind_gwlbe_outbound = "0.0.0.0/0"

### NATGW ###

nat_gateway_name = "natgw"

### GWLB ###

gateway_load_balancer_name                   = "security-gwlb"
gateway_load_balancer_endpoint_eastwest_name = "east-west-gwlb-endpoint"
gateway_load_balancer_endpoint_outbound_name = "outbound-gwlb-endpoint"

### TGW ###

transit_gateway_name            = "tgw"
transit_gateway_asn             = "65200"
transit_gateway_attachment_name = "security-vpc"
