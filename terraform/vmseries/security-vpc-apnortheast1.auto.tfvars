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

security_vpc_route_tables = {
  mgmt1            = { name = "mgmt1" }
  mgmt2            = { name = "mgmt2" }
  data1            = { name = "data1" }
  data2            = { name = "data2" }
  gwlbe-eastwest-1 = { name = "gwlbe-eastwest-1" }
  gwlbe-eastwest-2 = { name = "gwlbe-eastwest-2" }
  gwlbe-outbound-1 = { name = "gwlbe-outbound-1" }
  gwlbe-outbound-2 = { name = "gwlbe-outbound-2" }
  tgw-attach1      = { name = "tgw-attach1" }
  tgw-attach2      = { name = "tgw-attach2" }
  natgw1           = { name = "natgw1" }
  natgw2           = { name = "natgw2" }
}

security_vpc_subnets = {
  mgmt1            = { name = "mgmt1", cidr = "10.100.0.0/28", az = "ap-northeast-1a", rt = "mgmt1" }
  mgmt2            = { name = "mgmt2", cidr = "10.100.1.0/28", az = "ap-northeast-1c", rt = "mgmt2" }
  data1            = { name = "data1", cidr = "10.100.0.16/28", az = "ap-northeast-1a", rt = "data1" }
  data2            = { name = "data2", cidr = "10.100.1.16/28", az = "ap-northeast-1c", rt = "data2" }
  gwlbe-eastwest-1 = { name = "gwlbe-eastwest-1", cidr = "10.100.0.32/28", az = "ap-northeast-1a", rt = "gwlbe-eastwest-1" }
  gwlbe-eastwest-2 = { name = "gwlbe-eastwest-2", cidr = "10.100.1.32/28", az = "ap-northeast-1c", rt = "gwlbe-eastwest-2" }
  gwlbe-outbound-1 = { name = "gwlbe-outbound-1", cidr = "10.100.0.48/28", az = "ap-northeast-1a", rt = "gwlbe-outbound-1" }
  gwlbe-outbound-2 = { name = "gwlbe-outbound-2", cidr = "10.100.1.48/28", az = "ap-northeast-1c", rt = "gwlbe-outbound-2" }
  tgw-attach1      = { name = "tgw-attach1", cidr = "10.100.0.64/28", az = "ap-northeast-1a", rt = "tgw-attach1" }
  tgw-attach2      = { name = "tgw-attach2", cidr = "10.100.1.64/28", az = "ap-northeast-1c", rt = "tgw-attach2" }
  natgw1           = { name = "natgw1", cidr = "10.100.0.80/28", az = "ap-northeast-1a", rt = "natgw1" }
  natgw2           = { name = "natgw2", cidr = "10.100.1.80/28", az = "ap-northeast-1c", rt = "natgw2" }
}

security_nat_gateways = {
  natgw1 = { name = "public-1-natgw", subnet = "natgw1" }
  natgw2 = { name = "public-2-natgw", subnet = "natgw2" }
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

vpc_routes = {
  mgmt1-igw = {
    route_table   = "mgmt1"
    prefix        = "0.0.0.0/0"
    next_hop_type = "internet_gateway"
    next_hop_name = "vmseries-vpc"
  }
  mgmt2-igw = {
    route_table   = "mgmt2"
    prefix        = "0.0.0.0/0"
    next_hop_type = "internet_gateway"
    next_hop_name = "vmseries-vpc"
  }
  natgw1-igw = {
    route_table   = "natgw1"
    prefix        = "0.0.0.0/0"
    next_hop_type = "internet_gateway"
    next_hop_name = "vmseries-vpc"
  }
  natgw2-igw = {
    route_table   = "natgw2"
    prefix        = "0.0.0.0/0"
    next_hop_type = "internet_gateway"
    next_hop_name = "vmseries-vpc"
  }
  natgw1-to-gwlbe-outbound1 = {
    route_table   = "natgw1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "outbound1"
  }
  natgw2-to-gwlbe-outbound2 = {
    route_table   = "natgw2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "outbound2"
  }
  gwlbe-outbound1-to-natgw1 = {
    route_table   = "gwlbe-outbound-1"
    prefix        = "0.0.0.0/0"
    next_hop_type = "nat_gateway"
    next_hop_name = "natgw1"
  }
  gwlbe-outbound2-to-natgw2 = {
    route_table   = "gwlbe-outbound-2"
    prefix        = "0.0.0.0/0"
    next_hop_type = "nat_gateway"
    next_hop_name = "natgw2"
  }
  gwlbe-outbound1-to-tgw = {
    route_table   = "gwlbe-outbound-1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-outbound2-to-tgw = {
    route_table   = "gwlbe-outbound-2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-east-west-1-to-tgw = {
    route_table   = "gwlbe-eastwest-1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-east-west-2-to-tgw = {
    route_table   = "gwlbe-eastwest-2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-outbound1-to-tgw-test-spoke = {
    route_table   = "gwlbe-outbound-1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-outbound2-to-tgw-test-spoke = {
    route_table   = "gwlbe-outbound-2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-east-west-1-to-tgw-test-spoke = {
    route_table   = "gwlbe-eastwest-1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  gwlbe-east-west-2-to-tgw-test-spoke = {
    route_table   = "gwlbe-eastwest-2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "transit_gateway"
    next_hop_name = "gwlb"
  }
  tgw-attach-1-to-outbound-gwlbe-1 = {
    route_table   = "tgw-attach1"
    prefix        = "0.0.0.0/0"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "outbound1"
  }
  tgw-attach-2-to-outbound-gwlbe-2 = {
    route_table   = "tgw-attach2"
    prefix        = "0.0.0.0/0"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "outbound2"
  }
  tgw-attach-1-to-eastwest-gwlbe-1 = {
    route_table   = "tgw-attach1"
    prefix        = "10.0.0.0/8"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "east-west1"
  }
  tgw-attach-2-to-eastwest-gwlbe-2 = {
    route_table   = "tgw-attach2"
    prefix        = "10.0.0.0/8"
    next_hop_type = "vpc_endpoint"
    next_hop_name = "east-west2"
  }
}

### GWLB ###

gateway_load_balancer_subnets = ["gwlbe-eastwest-1", "gwlbe-eastwest-2"]

gateway_load_balancers = {
  security-gwlb = {
    name           = "security-gwlb"
    subnet_names   = ["data1", "data2"]
    firewall_names = ["vmseries01", "vmseries02"]
  }
}

gateway_load_balancer_endpoints = {
  east-west1 = {
    name                  = "east-west-gwlb-endpoint1"
    gateway_load_balancer = "security-gwlb"
    subnet_names          = ["gwlbe-eastwest-1"]
  }
  east-west2 = {
    name                  = "east-west-gwlb-endpoint2"
    gateway_load_balancer = "security-gwlb"
    subnet_names          = ["gwlbe-eastwest-2"]
  }
  outbound1 = {
    name                  = "outbound-gwlb-endpoint1"
    gateway_load_balancer = "security-gwlb"
    subnet_names          = ["gwlbe-outbound-1"]
  }
  outbound2 = {
    name                  = "outbound-gwlb-endpoint2"
    gateway_load_balancer = "security-gwlb"
    subnet_names          = ["gwlbe-outbound-2"]
  }
}


transit_gateways = {
  gwlb = {
    name = "tgw"
    asn  = "65200"
    route_tables = {
      security-in = { name = "from-security-vpc" }
      spoke-in    = { name = "from-spoke-vpcs" }
    }
  }
}

transit_gateway_vpc_attachments = {
  security = {
    name                                    = "security-vpc"
    vpc                                     = "vpc_id"
    appliance_mode_support                  = "enable"
    subnets                                 = ["tgw-attach1", "tgw-attach2"]
    transit_gateway                         = "gwlb"
    transit_gateway_route_table_association = "security-in"
    # transit_gateway_route_table_propagations = "security-in" # TODO
  }
}
