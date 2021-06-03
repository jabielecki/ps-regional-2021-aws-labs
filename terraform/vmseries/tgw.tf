module "security_vpc" {
  source          = "../modules/vpc"
  global_tags     = var.global_tags
  prefix_name_tag = var.prefix_name_tag
  name            = var.security_vpc_name
  vpc_endpoints   = var.security_vpc_endpoints
  security_groups = var.security_vpc_security_groups
  # ...

  igw_is_next_hop_for = {
    "from-mgmt-to-igw" = {
      from_subnet_set = module.subnet_set["mgmt"]
      to              = "0.0.0.0/0"
    }
    "from-natgw-to-igw" = {
      from_subnet_set = module.subnet_set["natgw"]
      to              = "0.0.0.0/0"
    }
  }
}

### NATGW ###

module "natgw" {
  # ...
  name       = var.nat_gateway_name
  subnet_set = module.subnet_set["natgw"]

  act_as_next_hop_for = {
    "from-gwlb-outbound-to-natgw" = {
      from_subnet_set = module.subnet_set["gwlb-outbound"]
      to              = var.summary_cidr_behind_natgw
    }
  }
}

### TGW ###

module transit_gateway {
  source = "../modules/transit_gateway"

  name            = var.transit_gateway_name
  asn             = var.transit_gateway_asn
  global_tags     = var.global_tags
  prefix_name_tag = var.prefix_name_tag
  vpc             = module.security_vpc

  route_tables = {
    security-in = { name = "from-security-vpc" }
    spoke-in    = { name = "from-spoke-vpcs" }
  }
}

# tgw module inputs:
#   Does it need `subnets`?
#   Does it need `vpc`?
# Open points:
#   - rename `act_as_next_hop_for` to `traffic_from`? 
#   - search everywhere for secondary modules/vpc_routes, what is the use case for vpc_routes_additional

module transit_gateway_vpc_attachment {
  name                                    = var.transit_gateway_vpc_attachment_name
  vpc                                     = module.vpc
  subnet_sets                             = [module.subnet_sets["tgw-attach"]]
  transit_gateway                         = module.transit_gateway
  transit_gateway_route_table_association = "security-in"
  appliance_mode_support                  = "enable"

  act_as_next_hop_for = {
    "from-gwlbe-outbound-to-tgw" = {
      from_subnet_set = module.subnet_set["gwlbe-outbound"]
      to              = var.summary_cidr_behind_tgw
    }
    "from-gwlbe-eastwest-to-tgw" = {
      from_subnet_set = module.subnet_set["gwlbe-eastwest"]
      to              = var.summary_cidr_behind_tgw
    }
  }
}

### GWLB ###

module "security_gwlb" {
  source                          = "../modules/gwlb"
  region                          = var.region
  name                            = var.gateway_load_balancer_name
  global_tags                     = var.global_tags
  prefix_name_tag                 = var.prefix_name_tag
  vpc_id                          = module.security_vpc.vpc_id.vpc_id
  subnet_set                      = "data" # assumption: one ss per gwlb
  firewall_names                  = ["vmseries01", "vmseries02"]
  gateway_load_balancer_endpoints = {} # separate modules now
}

module "gwlbe_eastwest" {
  name                  = var.gateway_load_balancer_endpoint_eastwest_name
  gateway_load_balancer = module.security_gwlb
  subnet_sets           = [module.subnet_set["gwlbe-eastwest"]]
  act_as_next_hop_for = {
    "from-tgw-to-gwlbe-eastwest" = {
      from_subnet_set = module.subnet_set["tgw-attach"]
      to              = var.summary_cidr_behind_tgw
    }
  }
}

module "gwlbe_outbound" {
  name                  = var.gateway_load_balancer_endpoint_outbound_name
  gateway_load_balancer = module.security_gwlb
  subnet_sets           = [module.subnet_set["gwlbe-outbound"]]
  act_as_next_hop_for = {
    "from-natgw-to-gwlbe-outbound" = {
      from_subnet_set = module.subnet_set["natgw"]
      to              = var.summary_cidr_behind_gwlbe_outbound
    }
    "from-tgw-to-gwlbe-outbound" = {
      from_subnet_set = module.subnet_set["tgw-attach"]
      to              = var.summary_cidr_behind_gwlbe_outbound
    }
  }
}

### App1 GWLB ###

module "app1_gwlbe_inbound" {
  name                  = var.gateway_load_balancer_endpoint_app1_name
  gateway_load_balancer = module.app1_gwlb
  subnet_sets           = [module.subnet_set["gwlbe"]]
  act_as_next_hop_for = {
    "from-igw-to-vpc-example" = {
      from_route_table_id = module.vpc.igw_edge_route_table_id
      to_entire_vpc       = true
    }
    "from-igw-to-alb" = {
      from_route_table_id = module.vpc.igw_edge_route_table_id
      to_subnet_set       = module.subnet_set["alb"]
    }
    # The routes above are special in that they are on the "edge", that is they are part of an IGW route table.
    # In such IGW routes only the following destinations are allowed by AWS:
    #     - The entire IPv4 or IPv6 CIDR block of your VPC. (First route above.)
    #     - The entire IPv4 or IPv6 CIDR block of a subnet in your VPC. (Second route above.)
    # Source: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html#gateway-route-table
    # The first route above (to_entire_vpc) is only here to illustrate the point. It should be removed 
    # in a real deployment.

    # Aside: a VPGW has the same rules, except it only supports individual NICs and no GWLBE (so, no balancing).
    # Looks like a temporary AWS limitation.

    # TODO: next hop "to_subnet_set" should handle subnets' secondary cidr blocks.
    # TODO: next hop "to_entire_vpc" should handle vpc's secondary cidr blocks.
  }
}
