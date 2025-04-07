resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.resource_group_name
  tags = {
    iac       = "terraform"
    iac-path  = "PrivateLinkDns"
  }
}

####################################
# Virtual Machines
#

######### Azure DNS Server ##############
resource "azurerm_public_ip" "az_dns_srv_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  name                = "az-dns-srv-pip"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "az_dns_srv_nic" {
  location            = azurerm_resource_group.rg.location
  name                = "az-dns-srv-nic"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.az_dns_srv_pip.id
    subnet_id                     = azurerm_subnet.az_hub_default_subnet.id
  }
}

resource "azurerm_windows_virtual_machine" "az_dns_srv" {
  admin_password                    = var.admin_password
  admin_username                    = var.admin_username
  hotpatching_enabled               = true
  license_type                      = "Windows_Server"
  location                          = azurerm_resource_group.rg.location
  name                              = "az-dns-srv"
  network_interface_ids             = [azurerm_network_interface.az_dns_srv_nic.id]
  patch_mode                        = "AutomaticByPlatform"
  reboot_setting                    = "IfRequired"
  resource_group_name               = var.resource_group_name
  secure_boot_enabled               = true
  size                              = "Standard_D2ds_v5"
  vm_agent_platform_updates_enabled = true
  vtpm_enabled                      = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition-hotpatch"
    version   = "latest"
  }
}

# # add custom script extension to az_dns_srv
# resource "azurerm_virtual_machine_extension" "az_dns_srv_custom_script" {
#   name                 = "az-dns-srv-custom-script"
#   virtual_machine_id   = azurerm_windows_virtual_machine.az_dns_srv.id
#   publisher           = "Microsoft.Compute"
#   type                = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = <<SETTINGS
#     {
#       "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \" winrm quickconfig -q; winrm set winrm/config/service/auth '@{Basic=\"true\"}'; winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}' try { winrm create winrm/config/Listener?Address=*+Transport=HTTP } catch { write-host \"Listener already exists\" }; netsh advfirewall firewall add rule name=\"WinRM\" dir=in action=allow protocol=TCP localport=5985; exit 0 \""
#     }
# SETTINGS
  
#   depends_on = [ azurerm_windows_virtual_machine.az_dns_srv ]
# }

######### DNS Client ##############
resource "azurerm_public_ip" "dns_client_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  name                = "dns-client-pip"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "dns_client_nic" {
  location            = azurerm_resource_group.rg.location
  name                = "dns-client-nic"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dns_client_pip.id 
    subnet_id                     = azurerm_subnet.spoke_default_subnet.id
  }
}

resource "azurerm_linux_virtual_machine" "dns_client" {
  admin_username                                         = var.admin_username
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  location                                               = azurerm_resource_group.rg.location
  name                                                   = "dns-client"
  network_interface_ids                                  = [azurerm_network_interface.dns_client_nic.id]
  patch_mode                                             = "AutomaticByPlatform"
  reboot_setting                                         = "IfRequired"
  resource_group_name                                    = var.resource_group_name
  secure_boot_enabled                                    = true
  size                                                   = "Standard_B1s"
  vtpm_enabled                                           = true
  additional_capabilities {
  }
  admin_ssh_key {
    public_key = var.public_key
    username   = var.admin_username
  }
  boot_diagnostics {
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "canonical"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  depends_on = [ azurerm_windows_virtual_machine.az_dns_srv ]
}

######### On-premises Client ############## 
resource "azurerm_public_ip" "onprem_client_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  name                = "onprem-client-pip"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "onprem_client_nic" {
  location            = azurerm_resource_group.rg.location
  name                = "onprem-client_nic"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onprem_client_pip.id
    subnet_id                     = azurerm_subnet.onprem_default_subnet.id
  }
}

resource "azurerm_linux_virtual_machine" "onprem_client" {
  admin_username                                         = var.admin_username
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  location                                               = azurerm_resource_group.rg.location
  name                                                   = "onprem-client"
  network_interface_ids                                  = [azurerm_network_interface.onprem_client_nic.id]
  patch_mode                                             = "AutomaticByPlatform"
  reboot_setting                                         = "IfRequired"
  resource_group_name                                    = azurerm_resource_group.rg.name
  secure_boot_enabled                                    = true
  size                                                   = "Standard_B1s"
  vtpm_enabled                                           = true
  additional_capabilities {
  }
  admin_ssh_key {
    public_key = var.public_key
    username   = var.admin_username
  }
  boot_diagnostics {
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "canonical"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  depends_on = [ azurerm_windows_virtual_machine.onprem_dns_srv ]
}

############ On-premises DNS Server ############################

resource "azurerm_public_ip" "onprem_dns_srv_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  name                = "onprem-dns-srv-pip"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "onprem_dns_srv_nic" {
  location            = azurerm_resource_group.rg.location
  name                = "onprem-dns-srv-nic"
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onprem_dns_srv_pip.id
    subnet_id                     = azurerm_subnet.onprem_default_subnet.id 
  }
}

resource "azurerm_windows_virtual_machine" "onprem_dns_srv" {
  admin_password                    = var.admin_password
  admin_username                    = var.admin_username
  hotpatching_enabled               = true
  license_type                      = "Windows_Server"
  location                          = azurerm_resource_group.rg.location
  name                              = "onprem-dns-srv"
  network_interface_ids             = [azurerm_network_interface.onprem_dns_srv_nic.id]
  patch_mode                        = "AutomaticByPlatform"
  reboot_setting                    = "IfRequired"
  resource_group_name               = var.resource_group_name
  secure_boot_enabled               = true
  size                              = "Standard_D2ds_v5"
  vm_agent_platform_updates_enabled = true
  vtpm_enabled                      = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition-hotpatch"
    version   = "latest"
  }
}


########################################################
# Network
# 

# az-hub-vnet
resource "azurerm_virtual_network" "az_hub_vnet" {
  address_space       = ["10.20.0.0/24"]
  location            = azurerm_resource_group.rg.location
  name                = "az-hub-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  dns_servers         = ["10.20.0.4"]
}

resource "azurerm_subnet" "az_hub_gw_subnet" {
  address_prefixes     = ["10.20.0.32/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.az_hub_vnet.name
}

resource "azurerm_subnet" "az_hub_default_subnet" {
  address_prefixes     = ["10.20.0.0/27"]
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.az_hub_vnet.name
}

# spoke-1
resource "azurerm_virtual_network" "spoke_1" {
  address_space        = ["10.20.1.0/24"]
  location             = azurerm_resource_group.rg.location
  name                 = "spoke-1"
  resource_group_name  = azurerm_resource_group.rg.name
  #dns_servers          = ["10.20.0.4"]
}

resource "azurerm_subnet" "spoke_default_subnet" {
  address_prefixes     = ["10.20.1.0/24"]
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  service_endpoints    = ["Microsoft.Storage"]
  virtual_network_name = azurerm_virtual_network.spoke_1.name
}

# onprem-vnet
resource "azurerm_virtual_network" "onprem_vnet" {
  address_space       = ["10.32.0.0/16"]
  location            = azurerm_resource_group.rg.location
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  #dns_servers          = ["10.32.1.4"]
}

resource "azurerm_subnet" "onprem_gw_subnet" {
  address_prefixes     = ["10.32.0.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
}

resource "azurerm_subnet" "onprem_default_subnet" {
  address_prefixes     = ["10.32.1.0/24"]
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
}

# peering hub-spoke

resource "azurerm_virtual_network_peering" "hub_2_spoke_1" {
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  name                      = "hub-2-spoke-1"
  remote_virtual_network_id = azurerm_virtual_network.spoke_1.id
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.az_hub_vnet.name
}

resource "azurerm_virtual_network_peering" "spoke_1_2_hub" {
  allow_forwarded_traffic   = true
  name                      = "spoke1-2-hub"
  remote_virtual_network_id = azurerm_virtual_network.az_hub_vnet.id
  resource_group_name       = azurerm_resource_group.rg.name
  use_remote_gateways       = false
  virtual_network_name      = azurerm_virtual_network.spoke_1.name
}

# peering onprem-hub

resource "azurerm_virtual_network_peering" "az_hub_to_onprem" {
  name                      = "az-hub-to-onprem"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.az_hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.onprem_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "onprem_to_az_hub" {
  name                      = "onprem-to-az-hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.onprem_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.az_hub_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}


####################################################
# NSG & rules

resource "azurerm_network_security_group" "nsg" {
  location            = azurerm_resource_group.rg.location
  name                = "nsg"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_dns_in_tcp" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "53"
  direction                   = "Inbound"
  name                        = "DNS-TCP"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_dns_in_udp" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "53"
  direction                   = "Inbound"
  name                        = "DNS-UDP"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 110
  protocol                    = "Udp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_dns_out_tcp" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "53"
  direction                   = "Outbound"
  name                        = "DNS-TCP"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 200
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "allow_dns_out_udp" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "53"
  direction                   = "Outbound"
  name                        = "DNS-UDP"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 210
  protocol                    = "Udp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"  
}

resource "azurerm_network_security_rule" "deny_rdp" {
  access                      = "Deny" # change this to "Allow" in case you need to manually connect to the VM
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "RDP"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 300
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

# required for ansible to work
resource "azurerm_network_security_rule" "allow_ssh" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "SSH"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 310
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

# allow port 5985 is a prerequisite for ansible to work
resource "azurerm_network_security_rule" "allow_winrm" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "5985"
  direction                   = "Inbound"
  name                        = "WinRM"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 320
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

# deny outbound internet but allow vnet connectivity to test arc private endpoints configuration
resource "azurerm_network_security_rule" "allow_outbpound_vnet" {
  access                      = "Allow"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "*"
  direction                   = "Outbound"
  name                        = "outbound-vnet"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 2990
  protocol                    = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "deny_outbpound_internet" {
  access                      = "Deny"
  destination_address_prefix  = "Internet"
  destination_port_range      = "*"
  direction                   = "Outbound"
  name                        = "outbound-internet"
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 3000
  protocol                    = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  source_address_prefix       = "*"
  source_port_range           = "*"
}

#
# DNS
#
resource "azurerm_virtual_network_dns_servers" "onprem_dns" {
  virtual_network_id = azurerm_virtual_network.onprem_vnet.id
  dns_servers        = [azurerm_windows_virtual_machine.onprem_dns_srv.private_ip_address]
}

resource "azurerm_virtual_network_dns_servers" "az_hub_dns" {
  virtual_network_id = azurerm_virtual_network.az_hub_vnet.id
  dns_servers        = [azurerm_windows_virtual_machine.az_dns_srv.private_ip_address]
}

resource "azurerm_virtual_network_dns_servers" "spoke_1_dns" {
  virtual_network_id = azurerm_virtual_network.spoke_1.id
  dns_servers        = [azurerm_windows_virtual_machine.az_dns_srv.private_ip_address]
}

resource "azurerm_private_dns_zone" "contoso_local" {
  name                = "contoso.local"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_hub_custom" {
  name                  = "link-hub-custom"
  private_dns_zone_name = azurerm_private_dns_zone.contoso_local.name
  registration_enabled  = true
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.az_hub_vnet.id
  #todo: when terraform supporta fallback_to_internet setting, set it to true 
  # fallback_to_internet = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_spoke1_custom" {
  name                  = "link-spoke1-custom"
  private_dns_zone_name = azurerm_private_dns_zone.contoso_local.name
  registration_enabled  = true
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.spoke_1.id
}

resource "azurerm_private_dns_zone" "privatelink_blob_core" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_hub_privatelink_blob_storage" {
  name                  = "vj7jwf2s7ll5c"
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_blob_core.name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.az_hub_vnet.id
   #todo: when terraform supporta fallback_to_internet setting, set it to true 
  # fallback_to_internet = true
}

resource "azurerm_private_endpoint" "pe_blob_storage" {
  location                          = azurerm_resource_group.rg.location
  name                              = "pe-dns-storage"
  resource_group_name               = azurerm_resource_group.rg.name
  subnet_id                         = azurerm_subnet.az_hub_default_subnet.id
  private_service_connection {
    name                            = "pe-dns-storage_e6f8b7b1-8f13-45d0-98ef-fedda437a040"
    private_connection_resource_id  = azurerm_storage_account.blobstorage.id
    subresource_names               = ["blob"]
    is_manual_connection            = false
  }
  private_dns_zone_group {
    name                            = "pe-dns-storage"
    private_dns_zone_ids            = [azurerm_private_dns_zone.privatelink_blob_core.id]
  }
  depends_on = [ azurerm_network_interface.az_dns_srv_nic ]
}


########################################################
# Storage Account

resource "azurerm_storage_account" "blobstorage" {
  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = false
  local_user_enabled              = false
  location                        = azurerm_resource_group.rg.location
  name                            = "mdnstafh53"
  resource_group_name             = azurerm_resource_group.rg.name
  # allow storage account key access so the automatically created event grid topic can be read by terraform
  shared_access_key_enabled = true  
}

########################################################
# nsg assignments

resource "azurerm_subnet_network_security_group_association" "onprem_default" {
  network_security_group_id = azurerm_network_security_group.nsg.id
  subnet_id                 = azurerm_subnet.onprem_default_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "az_hub_default" {
  network_security_group_id = azurerm_network_security_group.nsg.id
  subnet_id                 = azurerm_subnet.az_hub_default_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "spoke1_default" {
  network_security_group_id = azurerm_network_security_group.nsg.id
  subnet_id                 = azurerm_subnet.spoke_default_subnet.id
}