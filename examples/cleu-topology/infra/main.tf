provider "aws" {
  default_tags {
    tags = {
      "ios-xr:xrd:terraform"               = "true"
      "ios-xr:xrd:terraform-configuration" = "overlay-infra"
    }
  }
}

provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    config_path = local.bootstrap.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.bootstrap.kubeconfig_path
}

locals {
  name_prefix = local.bootstrap.name_prefix
}


resource "aws_subnet" "public_access" {
  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = "10.0.10.0/24"
  vpc_id            = local.bootstrap.vpc_id
  
  tags = {
    Name = "${local.name_prefix}-public-access"
  }
}

resource "aws_security_group" "public_access_security_group" {
  vpc_id = local.bootstrap.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_route_table" "public_route_table" {
  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_route_table_association" "public_access_subnet_association" {
  subnet_id = aws_subnet.public_access.id
  route_table_id = data.aws_route_table.public_route_table.id
}

data "aws_vpc" "selected" {
  id = local.bootstrap.vpc_id
}

resource "aws_subnet" "data" {
  for_each = {
    "trunk-1"  = ["10.0.11.0/24", cidrsubnet(data.aws_vpc.selected.ipv6_cidr_block, 8, 1)]
    "trunk-2"  = ["10.0.12.0/24", cidrsubnet(data.aws_vpc.selected.ipv6_cidr_block, 8, 2)]
    "access-b" = ["10.0.13.0/24", cidrsubnet(data.aws_vpc.selected.ipv6_cidr_block, 8, 3)]
  }

  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = each.value[0]
  vpc_id            = local.bootstrap.vpc_id

  // Assign an IPv6 CIDR block to the subnet
  ipv6_cidr_block = each.value[1]
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

resource "aws_security_group" "data" {
  name   = "${local.name_prefix}-data"
  vpc_id = local.bootstrap.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
}

module "eks_config" {
  source = "../../../modules/aws/eks-config"

  name_prefix       = local.name_prefix
  node_iam_role_arn = data.aws_iam_role.node.arn
  oidc_issuer       = local.bootstrap.oidc_issuer
  oidc_provider     = local.bootstrap.oidc_provider
}

module "xrd_ami" {
  source = "../../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = data.aws_eks_cluster.this.version
}

locals {
  public_access_subnet_id = aws_subnet.public_access.id
  trunk_1_subnet_id  = aws_subnet.data["trunk-1"].id
  trunk_2_subnet_id  = aws_subnet.data["trunk-2"].id
  access_b_subnet_id = aws_subnet.data["access-b"].id

  placement_group = (
    var.placement_group == null ?
    local.bootstrap.placement_group_name :
    var.placement_group
  )

  xrd_ami = coalesce(var.node_ami, module.xrd_ami[0].id)

  nodes = {
    alpha = {
      ami           = local.xrd_ami
      instance_type = var.node_instance_type
      security_groups = [
        local.bootstrap.bastion_security_group_id,
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
      ]
      private_ip_address = "10.0.100.11"
      subnet_id          = data.aws_subnet.cluster.id
      network_interfaces = [
        {
          subnet_id       = local.public_access_subnet_id
          private_ips     = ["10.0.10.11"]
          security_groups = [aws_security_group.public_access_security_group.id]
        },
        {
          subnet_id       = local.trunk_1_subnet_id
          private_ips     = ["10.0.11.11"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-1"].ipv6_cidr_block, 11)}"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = local.trunk_2_subnet_id
          private_ips     = ["10.0.12.11"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-2"].ipv6_cidr_block, 11)}"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      instance_type      = var.node_instance_type
      subnet_id          = data.aws_subnet.cluster.id
      private_ip_address = "10.0.100.12"
      security_groups = [
        local.bootstrap.bastion_security_group_id,
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
      ]
      network_interfaces = [
        {
          subnet_id       = local.public_access_subnet_id
          private_ips     = ["10.0.10.12"]
          security_groups = [aws_security_group.public_access_security_group.id]
        },
        {
          subnet_id       = local.trunk_1_subnet_id
          private_ips     = ["10.0.11.12"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-1"].ipv6_cidr_block, 12)}"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = local.trunk_2_subnet_id
          private_ips     = ["10.0.12.12"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-2"].ipv6_cidr_block, 12)}"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }

    gamma = {
      ami           = local.xrd_ami
      instance_type = var.node_instance_type
      security_groups = [
        local.bootstrap.bastion_security_group_id,
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
      ]
      private_ip_address = "10.0.100.13"
      subnet_id          = data.aws_subnet.cluster.id
      network_interfaces = [
        {
          subnet_id       = local.trunk_1_subnet_id
          private_ips     = ["10.0.11.13"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-1"].ipv6_cidr_block, 11)}"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = local.trunk_2_subnet_id
          private_ips     = ["10.0.12.13"]
          ipv6_addresses = ["${cidrhost(aws_subnet.data["trunk-2"].ipv6_cidr_block, 11)}"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }
  }
}

module "node" {
  source = "../../../modules/aws/node"

  for_each = local.nodes

  name                 = "${local.name_prefix}-${each.key}"
  ami                  = each.value.ami
  cluster_name         = local.bootstrap.cluster_name
  iam_instance_profile = local.bootstrap.node_iam_instance_profile_name
  instance_type        = each.value.instance_type
  key_name             = local.bootstrap.key_pair_name
  network_interfaces   = each.value.network_interfaces
  placement_group      = local.placement_group
  private_ip_address   = each.value.private_ip_address
  security_groups      = each.value.security_groups
  subnet_id            = each.value.subnet_id

  labels = {
    name = each.key
  }
}

resource "aws_eip" "public_gre_int_alpha" {
  domain = "vpc"
  network_interface = module.node["alpha"].network_interface[0].id
  associate_with_private_ip = "10.0.10.11"
}

resource "aws_eip" "public_gre_int_beta" {
  domain = "vpc"
  network_interface = module.node["beta"].network_interface[0].id
  associate_with_private_ip = "10.0.10.12"
}
