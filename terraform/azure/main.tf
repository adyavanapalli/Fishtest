terraform {
  cloud {
    organization = "adyavanapalli"
    workspaces {
      name = "Fishtest"
    }
  }
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  common_resource_suffix = "fishtest-${var.region}"
}

resource "azurerm_resource_group" "resource_group" {
  location = var.region
  name     = "rg-${local.common_resource_suffix}"
}

resource "azurerm_virtual_network" "virtual_network" {
  address_space       = ["10.0.0.0/29"]
  location            = var.region
  name                = "vnet-${local.common_resource_suffix}"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.0.0/29"]
  name                 = "snet-${local.common_resource_suffix}"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
}

resource "azurerm_public_ip" "public_ip" {
  allocation_method   = "Dynamic"
  location            = var.region
  name                = "pip-${local.common_resource_suffix}"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_network_interface" "network_interface" {
  ip_configuration {
    name                          = "nicipc-${local.common_resource_suffix}"
    private_ip_address_allocation = "Dynamic"
    #bridgecrew:skip=CKV_AZURE_119:Needed to SSH into the agent.
    public_ip_address_id = azurerm_public_ip.public_ip.id
    subnet_id            = azurerm_subnet.subnet.id
  }
  location            = var.region
  name                = "nic-${local.common_resource_suffix}"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 8192
}

data "azurerm_platform_image" "platform_image" {
  location  = var.region
  offer     = "0001-com-ubuntu-server-impish"
  publisher = "Canonical"
  sku       = "21_10-gen2"
}

resource "azurerm_linux_virtual_machine" "linux_virtual_machine" {
  admin_ssh_key {
    public_key = tls_private_key.private_key.public_key_openssh
    username   = var.username
  }
  admin_username             = var.username
  allow_extension_operations = false
  location                   = var.region
  name                       = "vm-${local.common_resource_suffix}"
  network_interface_ids      = [azurerm_network_interface.network_interface.id]
  os_disk {
    caching              = "None"
    name                 = "osdisk-${local.common_resource_suffix}"
    storage_account_type = "Standard_LRS"
  }
  resource_group_name = azurerm_resource_group.resource_group.name
  size                = var.virtual_machine_size
  source_image_reference {
    offer     = data.azurerm_platform_image.platform_image.offer
    publisher = data.azurerm_platform_image.platform_image.publisher
    sku       = data.azurerm_platform_image.platform_image.sku
    version   = data.azurerm_platform_image.platform_image.version
  }
}

# Azure Dynamic IP addresses are not allocated until they are associated with
# some entity, so here, we wait until the VM is created before fetching it using
# the `data` block type. This is later used in an output for constructing the
# appropriate SSH command.
data "azurerm_public_ip" "public_ip" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.resource_group.name

  depends_on = [
    azurerm_linux_virtual_machine.linux_virtual_machine
  ]
}
