# EKS cluster supporting multi-arch deployments

This Terraform repository automates the provisioning of an Amazon EKS cluster with Karpenter installed and configured. It also sets up node pools to manage different workload requirements efficiently.

## Prerequisites
Before you begin, ensure you have the following installed:

- Terraform (version >= 1.3.2)
- AWS CLI configured with appropriate permissions (version >= 2.17)
- kubectl configured to access the EKS cluster (version >= 1.30)

## Considerations

Given this is a standalone PoC meant to demonstrate the features of Karpenter, and not a full production deployment,certain decisions were made when it came to the implementation approach, with simplicity and speed in mind rather than flexibility. In a real-world production scenario, the following should be amended before deploying:

- The `cluster_endpoint_public_access` variable should be left to the default `false` value, and cluster network access should only be allowed via VPN or even better, VPN + a bastion host.

- A remote state should be used, instead of a local one

- Since the task explicitly mentioned "Terraform code that deploys an EKS cluster (whatever latest version is currently available) *into an existing VPC*" this deployment also includes a separate standalone module to deploy a VPC with the necessary subnets, rather than creating a VPC as part of the main Terraform module. To preserve the original requirement, I have tested this by first deploying the VPC using one statefile, then passed on the output as variable values to the EKS module in a separate deployment, with a separate statefile. In a real world scenario, these 2 modules would either be consolidated in a per-environment deployment, with the  outputs of the VPC module passed to the EKS one as inputs, or even better, the VPC deployments will be held in a separate statefile and the VPC and subnet IDs will be imported to the EKS one using the `terraform_remote_state` data source.

- The deployment and configuration of Karpenter is also handled via Terraform, in the form of manifests. While it is a valid approach, a probably better one would be using a GitOps tool like ArgoCD to deploy the helm chart for Karpenter, with the NodePool configs supplied from a separate repository as a set of K8s manifests, separating the underlying EKS configs (Terraform based) from the Node Pools (YAML based). Alternatively, a standalone TF module that handles all potential parameters that you might want to pass on to the NodeClass / NodePool would be a bear minimum, as the current implementation is mainly focused around the attributes relevant to architecture selection.

## Deploying the Terraform resources

In order to run the deployment, one should: 

a) Supply the variables (either shell variables prefixed with `TF_VAR_` or via .tfvars file) for the `project`, `environment` and `region`. These are used for both VPC and EKS deployments. 

b) Deploy the VPC resources (provided you don't have one deployed already):

```
cd terraform/vpc

terraform init
terraform apply  # with our without -var-file pointing at the .tfvars
```

Take note of the `vpc_id`, `private_subnets` and`intra_subnets` outputs

c) Set the necessary variables for the EKS deployment - review the README file in the module for an overview of mandatory and optional variables, or fill in the sample dev.tfvars file I provided. The mandatory variables are:

`project`, `environment`, `region`, `vpc_id`, `subnets_ids`, `control_plane_subnet_ids`

d) Deploy the EKS resources

```
cd terraform/eks

terraform init
terraform apply  # with our without -var-file pointing at the .tfvars
```

Once finished, you will have deployed a VPC, an EKS cluster, a managed node pool, the Karpeneter chart and associated NodeClass and NodePool resources.

## Deploying applications to run on selected architectures

In order to leverage Karpenter's ability to provision both x86 and ARM based nodes, you can make use of either the `NodeSelector` or `Tolerations` spec of your deployment config.

In order to achieve that, ensure that either your Kubernetes manifest (or helm chart values file) contains a toleration matching the Karpenter node's taint value for `kubernetes.io/arch`, or in case your Karpenter node doesn't use taints, an appropriate value for the NodeSelector spec. I have also attached 2 sample deployment manifests using the `inflate` app to showcase the taints and tolerations approach:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate-amd64
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate-amd64
  template:
    metadata:
      labels:
        app: inflate-amd64
    spec:
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.2
        name: inflate-amd64
        resources:
          requests:
            cpu: "1"
            memory: 256M
      tolerations:
      - key: "kubernetes.io/arch"
        operator: "Equal"
        value: "amd64"
        effect: "NoSchedule"
```

Given the `tolerations` section of the resource manifest has an entry matching the aforementioned `kubernetes.io/arch` key with a value of `amd-64`, the scheduler will be able to place the pod in question on one of the nodes with the respective taint - in our case, a Karpenter node running on a amd64 based node. 

Similarly, if the pod needs to be scheduled on a node running an ARM based Gravitron instance, the toleration can be changed to:

```
tolerations:
- key: "kubernetes.io/arch"
  operator: "Equal"
  value: "arm64"
  effect: "NoSchedule"
```

Alternatively, if you don't want to use taints on the nodes, you also have the option of using the `NodeSelector` attribute in the deployment spec. The concept is a bit simpler than taints and tolerations, since you simply use node labels to select a particular instance for scheduling the workload:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate-amd64
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate-amd64
  template:
    metadata:
      labels:
        app: inflate-amd64
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - image: public.ecr.aws/eks-distro/kubernetes/pause:3.2
        name: inflate-amd64
        resources:
          requests:
            cpu: "1"
            memory: 256M
```

This can achieve the same result, however it does come with the limitation that the nodes are not restricted to a particular type of workload, which is something you might want in a multi-arch scenario like this one, making taints and tolerations the preferred choice.

Once you have defined your deployment manifest and used the preferred node placement approach in the deployment spec, you just need to add the cluster credentials to your kubeconfig and deploy the manifest in the targeted namespace.

```
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl apply -f k8s-manifests/inflate-amd64 -n defautl
```