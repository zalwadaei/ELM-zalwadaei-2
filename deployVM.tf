terraform {
  backend "azurerm" {
    resource_group_name   = "DevOpsConfig"
    storage_account_name  = "saTerraform"
    container_name        = "terraform"
    key                   = "terraform.tfstate"
  }
}

provider "azurerm" {
    features { }
}

variable "RG" {
    default = "RG4"
}

variable "VM" {
    default = "VM1"
}

variable "VNET_ADDRESS" {
    default = "10.10.0.0/16"
}

variable "SUBNET_ADDRESS" {
    default = "10.10.0.0/24"
}

data "azurerm_key_vault" "keyvault" {
    name = "kvHRSConfig"
    resource_group_name = "DevOpsConfig" 
}

data "azurerm_key_vault_secret" "adminpwd" {
    name = "adminpwd"
    key_vault_id = data.azurerm_key_vault.keyvault.id
}

resource "azurerm_resource_group" "RG" {
  name = var.RG
  location = "West Europe"
}

resource "azurerm_virtual_network" "VNet" {
  name = "VNet1"
  address_space = [ var.VNET_ADDRESS ]
  location = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "Subnet1" {
  name = "FESubnet"
  address_prefixes = [ var.SUBNET_ADDRESS ]
  resource_group_name = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.VNet.name
}

resource "azurerm_public_ip" "Pip1" {
    name = "PipVM1"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    allocation_method = "Static"
    sku = "Standard"  
}

resource "azurerm_network_security_group" "NSG1" {
    name = "NsgVM1"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
}

resource "azurerm_network_security_rule" "RDP" {
  name = "AllowRDP"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "3389"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.NSG1.name
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_network_security_rule" "HTTP" {
  name = "AllowHTTP"
  priority = 101
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "80"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.NSG1.name
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_network_interface" "NIC1" {
    name = "NicVM1"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    ip_configuration {
        name = "ipconfigVM1"
        subnet_id = azurerm_subnet.Subnet1.id
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = azurerm_public_ip.Pip1.id  
    }
}

resource "azurerm_network_interface_security_group_association" "NsgToNic" {
    network_interface_id = azurerm_network_interface.NIC1.id 
    network_security_group_id = azurerm_network_security_group.NSG1.id 
}

resource "azurerm_virtual_machine" "VM1" {
    name = var.VM
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    network_interface_ids = [ azurerm_network_interface.NIC1.id ]
    vm_size = "Standard_D2S_v3"
    delete_os_disk_on_termination = true

    storage_image_reference {
      publisher = "MicrosoftWindowsServer"
      offer = "WindowsServer"
      sku = "2019-Datacenter"
      version = "latest"
    }
    storage_os_disk {
      name = "osdiskVM1"
      caching = "ReadWrite"
      create_option = "FromImage"
      managed_disk_type = "Premium_LRS"
    }

    os_profile {
      computer_name = "VM1"
      admin_username = "u2uadmin"
      admin_password = data.azurerm_key_vault_secret.adminpwd.value
    }

    os_profile_windows_config {
      provision_vm_agent = true
    }
}

