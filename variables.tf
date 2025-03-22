variable "location" {
  description = "The location where the resources will be created"
  type        = string
  default     = "germanywestcentral"
}

variable "admin_username" {
  description = "The admin username for the virtual machines"
  type        = string
}

variable "admin_password" {
  description = "The admin pw for the Windows virtual machines"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-privatelink-dns"
}

variable "public_key" {
  description = "The SSH public key for the admin user"
  type        = string
  sensitive   = true
}