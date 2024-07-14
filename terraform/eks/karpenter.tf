################################################################################
# Karpenter IAM
################################################################################

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = local.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

################################################################################
# Tagging private subnets for Karpenter auto-discovery
################################################################################

resource "aws_ec2_tag" "karpenter_autodiscovery_tag" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = "${local.cluster_name}"
}

################################################################################
# Karpenter Helm chart & manifests
################################################################################

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_chart_version
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]

  depends_on = [
    module.karpenter,
    aws_ec2_tag.karpenter_autodiscovery_tag
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

################################################################################
# Node Pools for Gravitron / x86 demo
################################################################################

resource "kubectl_manifest" "karpenter_node_pool_amd64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: amd64
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
          - key: "karpenter.k8s.aws/instance-cpu"
            operator: In
            values: ["4"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["spot"]
          - key: "karpenter.k8s.aws/instance-category"
            operator: In
            values: ["c", "m"]
          - key: "kubernetes.io/arch"
            operator: In
            values: ["amd64"]
          taints: 
          - key: "kubernetes.io/arch"
            value: "amd64"
            effect: NoSchedule
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_arm64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: arm64
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
          - key: "karpenter.k8s.aws/instance-cpu"
            operator: In
            values: ["4"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["spot"]
          - key: "karpenter.k8s.aws/instance-category"
            operator: In
            values: ["c", "m"]
          - key: "kubernetes.io/arch"
            operator: In
            values: ["arm64"]
          taints: 
          - key: "kubernetes.io/arch"
            value: "arm64"
            effect: NoSchedule
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}