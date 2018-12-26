variable client_id {}
variable client_secret {}

variable agent_count {
    default = 1
}

variable "vm_size" {
    default = "Standard_DS2_v2"
}

variable public_ssh_key_path {
    default = "~/.ssh/key.pub"
}

variable dns_prefix {
    default = "k8stest"
}

variable cluster_name {
    default = "k8stest"
}

variable kubernetes_version {
    default = "1.11.5"
}

variable "vnet_name" {
  default = "k8s-vnet"
}

variable "k8s_subnet_name" {
  default = "k8s-subnet"
}

variable "vm_subnet_name" {
  default = "vms-subnet"
}

variable resource_group_name {
    default = "AKS"
}

variable location {
    default = "West Europe"
}

variable log_analytics_workspace_name {
    default = "k8snenadtest"
}