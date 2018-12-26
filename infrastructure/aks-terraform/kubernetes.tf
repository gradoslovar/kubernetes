# Configure the Microsoft Azure Provider
provider "azurerm" {
    version = "~>1.6"
}

terraform {
    backend "azurerm" {}
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "k8s-rg" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "k8s-log" {
  name                = "${var.log_analytics_workspace_name}"
  location            = "${azurerm_resource_group.k8s-rg.location}"
  resource_group_name = "${azurerm_resource_group.k8s-rg.name}"
  sku                 = "Free"
}

# Create Container Insights Solution
resource "azurerm_log_analytics_solution" "k8s-monitor" {
  solution_name         = "ContainerInsights"
  location              = "${azurerm_resource_group.k8s-rg.location}"
  resource_group_name   = "${azurerm_resource_group.k8s-rg.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.k8s-log.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.k8s-log.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# Create virtual network for kubernetes
resource "azurerm_virtual_network" "k8s-vnet" {
  name                = "${var.vnet_name}"
  location            = "${azurerm_resource_group.k8s-rg.location}"
  resource_group_name = "${azurerm_resource_group.k8s-rg.name}"
  address_space = ["192.168.100.0/24"]
}

# Create vnet subnet for Kubernetes
resource "azurerm_subnet" "k8s-subnet" {
  name                 = "${var.k8s_subnet_name}"
  resource_group_name  = "${azurerm_resource_group.k8s-rg.name}"
  address_prefix       = "192.168.100.0/25"
  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql"]
}

# Create vnet subnet for Windows servers
resource "azurerm_subnet" "vm-subnet" {
  name                 = "${var.vm_subnet_name}"
  resource_group_name  = "${azurerm_resource_group.k8s-rg.name}"
  address_prefix       = "192.168.100.128/26"
  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
  service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql"]
}

# Create k8s cluster

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = "${var.cluster_name}"
    location            = "${azurerm_resource_group.k8s-rg.location}"
    resource_group_name = "${azurerm_resource_group.k8s-rg.name}"
    dns_prefix          = "${var.dns_prefix}"
    kubernetes_version  = "${var.kubernetes_version}"

    # linux_profile {
    #     admin_username = "alsid"

    #     ssh_key {
    #     key_data = "${file(var.public_ssh_key_path)}"
    #     }
    # }
    
    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.agent_count}"
        vm_size         = "${var.vm_size}"
        os_type         = "Linux"
        os_disk_size_gb = 30
        vnet_subnet_id = "${azurerm_subnet.k8s-subnet.id}"
        # max_pods = 100 # if one wants to set number of pods diffrent from defaults 30
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }

    network_profile {
        network_plugin = "azure"
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8s-log.id}"
        }
    }

    # tags {
    #     Environment = "Development"
    # }
}

