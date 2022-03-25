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

locals {
  key_vault_prefix          = "kv-"
  key_vault_suffix          = "-eastus"
  key_vault_name_max_length = 24
}

resource "random_string" "key_vault_infix" {
  length  = local.key_vault_name_max_length - length(local.key_vault_prefix) - length(local.key_vault_suffix)
  special = false
}

resource "azurerm_key_vault" "key_vault" {
  location = var.region
  name     = "${local.key_vault_prefix}${random_string.key_vault_infix.result}${local.key_vault_suffix}"
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
  purge_protection_enabled = true
  resource_group_name      = azurerm_resource_group.resource_group.name
  soft_delete_enabled      = true
  sku_name                 = "standard"
  tenant_id                = var.tenant_id
}

resource "azurerm_key_vault_key" "key_vault_key" {
  expiration_date = "2022-12-31T23:59:59Z"
  key_size        = 4096
  #bridgecrew:skip=CKV_AZURE_112:No RSA-HSM needed for this use-case.
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "kvk-${local.common_resource_suffix}"
}

data "azurerm_platform_image" "platform_image" {
  location  = var.region
  offer     = "0001-com-ubuntu-server-impish"
  publisher = "Canonical"
  sku       = "21_10-gen2"
}

resource "azurerm_linux_virtual_machine" "linux_virtual_machine" {
  admin_ssh_key {
    public_key = azurerm_key_vault_key.key_vault_key.public_key_openssh
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
