# File: /terraform/modules/vm/outputs.tf
variable "os_type" {
  description = "Typ systemu operacyjnego (linux lub windows)"
  type        = string
}

variable "image_name" {
  description = "Nazwa obrazu systemu operacyjnego"
  type        = string
}

variable "user_id" {
  description = "ID użytkownika"
  type        = string
}

variable "admin_username" {
  description = "Nazwa użytkownika administratora"
  type        = string
}

variable "admin_password" {
  description = "Hasło administratora (tylko dla Windows)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Klucz publiczny SSH (tylko dla Linux)"
  type        = string
}

variable "resource_group_name" {
  description = "Nazwa grupy zasobów"
  type        = string
}

variable "location" {
  description = "Lokalizacja zasobów"
  type        = string
}

variable "network_interface_id" {
  description = "ID interfejsu sieciowego"
  type        = string
}

variable "subscription_id" {
  description = "ID subskrypcji Azure"
  type        = string
}
variable "tags" {
  description = "Tagi do przypisania zasobom"
  type        = map(string)
}

variable "custom_image_id" {
  type        = string
  default     = null
}