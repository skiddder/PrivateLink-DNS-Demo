# add public ip of the dns-client
output "dns_client_public_ip" {
  value = azurerm_public_ip.dns_client_pip.ip_address
}

output "onprem_client_public_ip" {
  value = azurerm_public_ip.onprem_client_pip.ip_address
}

output "az_dns_srv_public_ip" {
  value = azurerm_public_ip.az_dns_srv_pip.ip_address
}

output "onprem_dns_srv_public_ip" {
  value = azurerm_public_ip.onprem_dns_srv_pip.ip_address
}