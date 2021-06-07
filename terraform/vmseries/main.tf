module "vmseries" {
  source              = "../modules/vmseries"
  region              = var.region
  prefix_name_tag     = var.prefix_name_tag
  ssh_key_name        = var.ssh_key_name
  fw_license_type     = var.fw_license_type
  fw_version          = var.fw_version
  fw_instance_type    = var.fw_instance_type
  tags                = var.global_tags
  firewalls           = var.firewalls
  interfaces          = var.interfaces
  subnets_map         = module.security_vpc.subnet_ids
  security_groups_map = module.security_vpc.security_group_ids
  # addtional_interfaces = var.addtional_interfaces
}

### AMI and startup script for web servers in spokes

data "aws_ami" "amazon-linux-2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

locals {
  web_user_data = <<EOF
#!/bin/bash
sleep 120;
until sudo yum update -y; do echo "Retrying"; sleep 5; done
until sudo yum install -y php; do echo "Retrying"; sleep 5; done
until sudo yum install -y httpd; do echo "Retrying"; sleep 5; done
until sudo rm -f /var/www/html/index.html; do echo "Retrying"; sleep 5; done
until sudo wget -O /var/www/html/index.php https://raw.githubusercontent.com/wwce/terraform/master/gcp/adv_peering_2fw_2spoke_common/scripts/showheaders.php; do echo "Retrying"; sleep 2; done
until sudo systemctl start httpd; do echo "Retrying"; sleep 5; done
until sudo systemctl enable httpd; do echo "Retrying"; sleep 5; done
EOF
}


### Module calls for app2 VPC

module "app1_vpc" {
  source           = "../modules/vpc"
  global_tags      = var.global_tags
  prefix_name_tag  = var.prefix_name_tag
  vpc              = var.app1_vpc
  vpc_route_tables = var.app1_vpc_route_tables
  subnets          = var.app1_vpc_subnets
  vpc_endpoints    = var.app1_vpc_endpoints
  security_groups  = var.app1_vpc_security_groups
}

module "app1_vpc_routes" {
  source            = "../modules/vpc_routes"
  region            = var.region
  global_tags       = var.global_tags
  prefix_name_tag   = var.prefix_name_tag
  vpc_routes        = var.app1_vpc_routes
  vpc_route_tables  = module.app1_vpc.route_table_ids
  internet_gateways = module.app1_vpc.internet_gateway_id
  nat_gateways      = module.app1_vpc.nat_gateway_ids
  vpc_endpoints     = module.app1_gwlb.endpoint_ids
  transit_gateways  = module.app1_transit_gateways.transit_gateway_ids
}

module "app1_vpc_routes_additional" {
  source            = "../modules/vpc_routes"
  region            = var.region
  global_tags       = var.global_tags
  prefix_name_tag   = var.prefix_name_tag
  vpc_routes        = var.app1_vpc_routes_additional
  vpc_route_tables  = module.app1_vpc.route_table_ids
  internet_gateways = module.app1_vpc.internet_gateway_id
  nat_gateways      = module.app1_vpc.nat_gateway_ids
  vpc_endpoints     = module.app1_gwlb.endpoint_ids
  transit_gateways  = module.app1_transit_gateways.transit_gateway_ids
}

module "app1_transit_gateways" {
  source                      = "../modules/transit_gateway"
  global_tags                 = var.global_tags
  prefix_name_tag             = var.prefix_name_tag
  subnets                     = module.app1_vpc.subnet_ids
  vpcs                        = module.app1_vpc.vpc_id
  transit_gateways            = var.app1_transit_gateways
  transit_gateway_attachments = var.app1_transit_gateway_attachments
  depends_on                  = [module.gwlb] # Depends on GWLB being created in security VPC
}

module "app1_gwlb" {
  source                          = "../modules/gwlb"
  region                          = var.region
  global_tags                     = var.global_tags
  prefix_name_tag                 = var.prefix_name_tag
  vpc_id                          = module.app1_vpc.vpc_id.vpc_id
  gateway_load_balancers          = var.app1_gateway_load_balancers
  gateway_load_balancer_endpoints = var.app1_gateway_load_balancer_endpoints
  subnets_map                     = module.app1_vpc.subnet_ids
  depends_on                      = [module.transit_gateways] # Depends on GWLB being created in security VPC
}

module "app1_ec2_cluster" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name                        = "${var.prefix_name_tag}app1-web"
  instance_count              = 2
  associate_public_ip_address = false

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = var.ssh_key_name
  monitoring             = true
  vpc_security_group_ids = [module.app1_vpc.security_group_ids["web-server-sg"]]
  subnet_ids             = [module.app1_vpc.subnet_ids["web1"], module.app1_vpc.subnet_ids["web2"]]
  user_data_base64       = base64encode(local.web_user_data)
  tags                   = var.global_tags
}


##################################################################
# Network Load Balancer with Elastic IPs attached
##################################################################
module "app1_nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.prefix_name_tag}app1-nlb"

  load_balancer_type = "network"

  vpc_id = module.app1_vpc.vpc_id["vpc_id"]

  #   Use `subnets` if you don't want to attach EIPs
  subnets = [module.app1_vpc.subnet_ids["alb1"], module.app1_vpc.subnet_ids["alb2"]]

  #  TCP_UDP, UDP, TCP
  http_tcp_listeners = [
    {
      port               = 22
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name             = "${var.prefix_name_tag}app1-ssh"
      backend_protocol = "TCP"
      backend_port     = 22
      target_type      = "instance"
    },
    {
      name             = "${var.prefix_name_tag}app1-http"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]
}

resource "aws_lb_target_group_attachment" "app1_ssh" {
  count            = 2
  target_group_arn = module.app1_nlb.target_group_arns[0]
  target_id        = module.app1_ec2_cluster.id[count.index]
}

resource "aws_lb_target_group_attachment" "app1_http" {
  count            = 2
  target_group_arn = module.app1_nlb.target_group_arns[1]
  target_id        = module.app1_ec2_cluster.id[count.index]
}


### Module calls for app2 VPC

module "app2_vpc" {
  source           = "../modules/vpc"
  global_tags      = var.global_tags
  prefix_name_tag  = var.prefix_name_tag
  vpc              = var.app2_vpc
  vpc_route_tables = var.app2_vpc_route_tables
  subnets          = var.app2_vpc_subnets
  vpc_endpoints    = var.app2_vpc_endpoints
  security_groups  = var.app2_vpc_security_groups
}


module "app2_vpc_routes" {
  source            = "../modules/vpc_routes"
  region            = var.region
  global_tags       = var.global_tags
  prefix_name_tag   = var.prefix_name_tag
  vpc_routes        = var.app2_vpc_routes
  vpc_route_tables  = module.app2_vpc.route_table_ids
  internet_gateways = module.app2_vpc.internet_gateway_id
  nat_gateways      = module.app2_vpc.nat_gateway_ids
  vpc_endpoints     = module.app2_gwlb.endpoint_ids
  transit_gateways  = module.app2_transit_gateways.transit_gateway_ids
}

module "app2_vpc_routes_additional" {
  source            = "../modules/vpc_routes"
  region            = var.region
  global_tags       = var.global_tags
  prefix_name_tag   = var.prefix_name_tag
  vpc_routes        = var.app2_vpc_routes_additional
  vpc_route_tables  = module.app2_vpc.route_table_ids
  internet_gateways = module.app2_vpc.internet_gateway_id
  nat_gateways      = module.app2_vpc.nat_gateway_ids
  vpc_endpoints     = module.app2_gwlb.endpoint_ids
  transit_gateways  = module.app2_transit_gateways.transit_gateway_ids
}

module "app2_transit_gateways" {
  source                      = "../modules/transit_gateway"
  global_tags                 = var.global_tags
  prefix_name_tag             = var.prefix_name_tag
  subnets                     = module.app2_vpc.subnet_ids
  vpcs                        = module.app2_vpc.vpc_id
  transit_gateways            = var.app2_transit_gateways
  transit_gateway_attachments = var.app2_transit_gateway_attachments
  depends_on                  = [module.gwlb] # Depends on GWLB being created in security VPC
}

module "app2_gwlb" {
  source                          = "../modules/gwlb"
  region                          = var.region
  global_tags                     = var.global_tags
  prefix_name_tag                 = var.prefix_name_tag
  vpc_id                          = module.app2_vpc.vpc_id.vpc_id
  gateway_load_balancers          = var.app2_gateway_load_balancers
  gateway_load_balancer_endpoints = var.app2_gateway_load_balancer_endpoints
  subnets_map                     = module.app2_vpc.subnet_ids
  depends_on                      = [module.transit_gateways] # Depends on GWLB being created in security VPC
}


module "app2_ec2_cluster" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name                        = "${var.prefix_name_tag}app2-web"
  instance_count              = 2
  associate_public_ip_address = false

  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t2.micro"
  key_name               = var.ssh_key_name
  monitoring             = true
  vpc_security_group_ids = [module.app2_vpc.security_group_ids["web-server-sg"]]
  subnet_ids             = [module.app2_vpc.subnet_ids["web1"], module.app2_vpc.subnet_ids["web2"]]
  user_data_base64       = base64encode(local.web_user_data)
  tags                   = var.global_tags
}


##################################################################
# Network Load Balancer with Elastic IPs attached
##################################################################
module "app2_nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.prefix_name_tag}app2-nlb"

  load_balancer_type = "network"

  vpc_id = module.app2_vpc.vpc_id["vpc_id"]

  #   Use `subnets` if you don't want to attach EIPs
  subnets = [module.app2_vpc.subnet_ids["alb1"], module.app2_vpc.subnet_ids["alb2"]]

  #  TCP_UDP, UDP, TCP
  http_tcp_listeners = [
    {
      port               = 22
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name             = "${var.prefix_name_tag}app2-ssh"
      backend_protocol = "TCP"
      backend_port     = 22
      target_type      = "instance"
    },
    {
      name             = "${var.prefix_name_tag}app2-http"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]
}

resource "aws_lb_target_group_attachment" "app2_ssh" {
  count            = 2
  target_group_arn = module.app2_nlb.target_group_arns[0]
  target_id        = module.app2_ec2_cluster.id[count.index]
}

resource "aws_lb_target_group_attachment" "app2_http" {
  count            = 2
  target_group_arn = module.app2_nlb.target_group_arns[1]
  target_id        = module.app2_ec2_cluster.id[count.index]
}
