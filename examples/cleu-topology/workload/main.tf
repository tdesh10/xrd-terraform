provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    config_path = local.infra.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.infra.kubeconfig_path
}

locals {
  image_repository = format(
    "%s/%s",
    coalesce(
      var.image_registry,
      format(
        "%s.dkr.ecr.%s.amazonaws.com",
        data.aws_caller_identity.current.account_id,
        data.aws_region.current.name,
      ),
    ),
    var.image_repository,
  )
}

module "node_props" {
  source = "../../../modules/aws/node-props"

  for_each = data.aws_instance.nodes

  instance_type = each.value.instance_type
  use_case      = "maximal"
}

resource "helm_release" "xrd1" {
  name       = "xrd1"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd1.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = module.node_props["alpha"].cpuset
      },
    )
  ]
}

resource "helm_release" "xrd2" {
  name       = "xrd2"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd2.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = module.node_props["beta"].cpuset
      },
    )
  ]
}
resource "helm_release" "xrd3" {
  name       = "xrd3"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd3.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = module.node_props["beta"].cpuset
      },
    )
  ]
}

# module "cnf" {
#   source = "../../../modules/aws/linux-pod-with-net-attach"

#   name       = "cnf"
#   device     = "eth1"
#   ip_address = "10.0.10.10/24"
#   gateway    = "10.0.10.11"
#   routes     = ["10.0.13.0/24"]
#   node_selector = {
#     name = "gamma"
#   }
# }

# module "peer" {
#   source = "../../../modules/aws/linux-pod-with-net-attach"

#   name       = "peer"
#   device     = "eth2"
#   ip_address = "10.0.13.10/24"
#   gateway    = "10.0.13.12"
#   routes     = ["10.0.10.0/24"]
#   node_selector = {
#     name = "gamma"
#   }
# }
