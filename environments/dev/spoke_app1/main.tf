provider "azurerm" {
  features {}
}

data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateXXXX"
    container_name       = "platform-dev"
    key                  = "hub.tfstate"
  }
}

resource "azurerm_resource_group" "spoke_net" {
  name     = "rg-spoke-net-dev"
  location = "westeurope"
}

resource "azurerm_resource_group" "spoke_compute" {
  name     = "rg-spoke-compute-dev"
  location = "westeurope"
}

module "spoke_vnet" {
  source              = "git::https://github.com/my-practice-development/terraform-modules.git//network/vnet"
  name                = "vnet-spoke-dev"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.spoke_net.name
  address_space       = ["10.1.0.0/16"]
}

module "spoke_subnet_web" {
  source              = "git::https://github.com/my-practice-development/terraform-modules.git//network/subnet"
  name                = "snet-web"
  resource_group_name = azurerm_resource_group.spoke_net.name
  vnet_name           = module.spoke_vnet.name
  address_prefixes    = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "vm" {
  name                = "pip-spoke-vm-dev"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.spoke_compute.name
  allocation_method   = "Dynamic"
}

module "vm" {
  source              = "git::https://github.com/my-practice-development/terraform-modules.git//compute/vm-linux"
  name                = "vm-nginx-dev"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.spoke_compute.name
  subnet_id           = module.spoke_subnet_web.id
  admin_username      = "azureuser"
  public_ip_id        = azurerm_public_ip.vm.id
}

module "peer_spoke_to_hub" {
  source              = "git::https://github.com/my-practice-development/terraform-modules.git//network/vnet-peering"
  name                = "spoke-to-hub"
  resource_group_name = azurerm_resource_group.spoke_net.name
  vnet_name           = module.spoke_vnet.name
  remote_vnet_id      = data.terraform_remote_state.platform.outputs.hub_vnet_id
}

module "peer_hub_to_spoke" {
  source              = "git::https://github.com/my-practice-development/terraform-modules.git//network/vnet-peering"
  name                = "hub-to-spoke"
  resource_group_name = data.terraform_remote_state.platform.outputs.hub_rg_name
  vnet_name           = data.terraform_remote_state.platform.outputs.hub_vnet_name
  remote_vnet_id      = module.spoke_vnet.id
}
